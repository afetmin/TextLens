import AppKit
import ApplicationServices
import Foundation
import TextLensCore

protocol SelectionReading {
    static var isTrusted: Bool { get }
    func readSelection(policy: SelectionCapturePolicy) throws -> RawSelection
}

enum SelectionReadError: LocalizedError {
    case permissionMissing
    case noFrontmostApplication
    case noFocusedElement
    case noSelectedText

    var errorDescription: String? {
        switch self {
        case .permissionMissing:
            "需要辅助功能权限"
        case .noFrontmostApplication:
            "没有前台应用"
        case .noFocusedElement:
            "当前应用没有可读取的焦点控件"
        case .noSelectedText:
            "当前应用未暴露选中文本"
        }
    }
}

struct AccessibilitySelectionReader: SelectionReading {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func readSelection(policy: SelectionCapturePolicy) throws -> RawSelection {
        guard Self.isTrusted else {
            throw SelectionReadError.permissionMissing
        }
        guard let app = NSWorkspace.shared.frontmostApplication else {
            throw SelectionReadError.noFrontmostApplication
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        if let focused = copyAttribute(kAXFocusedUIElementAttribute, from: appElement),
           let selectedText = copyStringAttribute(kAXSelectedTextAttribute, from: focused),
           !selectedText.isEmpty {
            return RawSelection(text: selectedText, sourceBundleID: app.bundleIdentifier)
        }

        if let selectedText = copyStringAttribute(kAXSelectedTextAttribute, from: appElement), !selectedText.isEmpty {
            return RawSelection(text: selectedText, sourceBundleID: app.bundleIdentifier)
        }

        if policy.allowsCopyFallback,
           let copied = CopySelectionFallback.copySelection(sourceBundleID: app.bundleIdentifier) {
            return copied
        }

        throw SelectionReadError.noSelectedText
    }

    private func copyAttribute(_ attribute: String, from element: AXUIElement) -> AXUIElement? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard error == .success else { return nil }
        return value as? String
    }
}

@MainActor
final class GlobalSelectionMonitor {
    private let reader: SelectionReading
    private let pipeline: SelectionCapturePipeline
    private let onSnapshot: (SelectionSnapshot) -> Void
    private let onStatus: (String) -> Void
    private var monitors: [Any] = []
    private var pendingCapture: Task<Void, Never>?

    init(
        reader: SelectionReading,
        gate: SelectionEventGate,
        onSnapshot: @escaping (SelectionSnapshot) -> Void,
        onStatus: @escaping (String) -> Void
    ) {
        self.reader = reader
        self.pipeline = SelectionCapturePipeline(eventGate: gate)
        self.onSnapshot = onSnapshot
        self.onStatus = onStatus
    }

    func start() -> Bool {
        guard monitors.isEmpty else { return true }
        guard type(of: reader).isTrusted else {
            onStatus("需要辅助功能权限")
            return false
        }

        let mouseMask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp]
        if let mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mouseMask, handler: { [weak self] event in
            let anchor = NSEvent.mouseLocation
            guard let triggerEvent = SelectionTriggerEvent(event: event, anchor: anchor) else { return }
            Task { @MainActor in
                guard let request = self?.pipeline.observe(triggerEvent) else { return }
                self?.scheduleCapture(request)
            }
        }) {
            monitors.append(mouseMonitor)
        }

        if let keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyUp, handler: { [weak self] event in
            let anchor = NSEvent.mouseLocation
            let triggerEvent = SelectionTriggerEvent(
                kind: .keyUp,
                timestamp: event.timestamp,
                location: anchor,
                keyCode: event.keyCode,
                modifiers: SelectionTriggerModifiers(event.modifierFlags)
            )
            Task { @MainActor in
                guard let request = self?.pipeline.observe(triggerEvent) else { return }
                self?.scheduleCapture(request)
            }
        }) {
            monitors.append(keyMonitor)
        }

        onStatus("划词自动弹出已开启")
        return !monitors.isEmpty
    }

    func stop() {
        pendingCapture?.cancel()
        pendingCapture = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
    }

    func resetSelectionHistory() {
        pipeline.reset()
    }

    private func scheduleCapture(_ request: SelectionCaptureRequest) {
        pendingCapture?.cancel()
        pendingCapture = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 160_000_000)
            guard !Task.isCancelled else { return }
            do {
                let raw = try reader.readSelection(policy: request.policy)
                guard let snapshot = pipeline.snapshot(
                    for: raw,
                    anchor: request.anchor,
                    at: Date()
                ) else {
                    return
                }
                onSnapshot(snapshot)
            } catch {
                onStatus(error.localizedDescription)
            }
        }
    }
}

private extension SelectionTriggerEvent {
    init?(event: NSEvent, anchor: CGPoint) {
        guard let mouseKind = SelectionTriggerMouseKind(event.type) else {
            return nil
        }

        self.init(
            kind: .mouse(mouseKind),
            timestamp: event.timestamp,
            location: anchor,
            modifiers: SelectionTriggerModifiers(event.modifierFlags)
        )
    }
}

private extension SelectionTriggerMouseKind {
    init?(_ eventType: NSEvent.EventType) {
        switch eventType {
        case .leftMouseDown:
            self = .leftMouseDown
        case .leftMouseDragged:
            self = .leftMouseDragged
        case .leftMouseUp:
            self = .leftMouseUp
        default:
            return nil
        }
    }
}

private extension SelectionTriggerModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        let masked = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: SelectionTriggerModifiers = []
        if masked.contains(.shift) {
            modifiers.insert(.shift)
        }
        if masked.contains(.command) {
            modifiers.insert(.command)
        }
        if masked.contains(.option) {
            modifiers.insert(.option)
        }
        if masked.contains(.control) {
            modifiers.insert(.control)
        }
        self = modifiers
    }
}

private enum CopySelectionFallback {
    static func copySelection(sourceBundleID: String?) -> RawSelection? {
        let pasteboard = NSPasteboard.general
        let previous = PasteboardSnapshot.capture(from: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        sendCopyShortcut()

        let deadline = Date().addingTimeInterval(0.45)
        var copiedText: String?
        repeat {
            if pasteboard.changeCount != previousChangeCount,
               let text = pasteboard.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty {
                copiedText = text
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.025))
        } while Date() < deadline

        previous.restore(to: pasteboard)

        guard let copiedText else { return nil }
        return RawSelection(text: copiedText, sourceBundleID: sourceBundleID)
    }

    private static func sendCopyShortcut() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyCodeForC: CGKeyCode = 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForC, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForC, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}

private struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]] = pasteboard.pasteboardItems?.map { item in
            var captured: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    captured[type] = data
                }
            }
            return captured
        } ?? []
        return PasteboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let restoredItems = items.map { captured in
            let item = NSPasteboardItem()
            for (type, data) in captured {
                item.setData(data, forType: type)
            }
            return item
        }
        if !restoredItems.isEmpty {
            pasteboard.writeObjects(restoredItems)
        }
    }
}
