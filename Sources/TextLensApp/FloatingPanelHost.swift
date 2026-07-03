import AppKit
import TextLensCore

@MainActor
final class FloatingPanelHost {
    private var panel: NSPanel?
    private var dismissMonitor: Any?
    private let initialSize: NSSize

    init(initialSize: NSSize) {
        self.initialSize = initialSize
    }

    var visibleFrame: NSRect? {
        guard let panel, panel.isVisible else { return nil }
        return panel.frame
    }

    var visiblePanel: NSPanel? {
        guard let panel, panel.isVisible else { return nil }
        return panel
    }

    func panel(makeContentView: () -> NSView) -> NSPanel {
        if let panel {
            return panel
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: initialSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.contentView = makeContentView()
        self.panel = panel
        return panel
    }

    func close(animated: Bool = true, duration: TimeInterval) {
        stopDismissMonitor()
        guard let panel, panel.isVisible else { return }
        guard animated else {
            panel.orderOut(nil)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 0
        } completionHandler: {
            Task { @MainActor in
                panel.orderOut(nil)
                panel.alphaValue = 1
            }
        }
    }

    func fadeIn(duration: TimeInterval) {
        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
    }

    func startDismissMonitor(onDismiss: @escaping @MainActor () -> Void) {
        stopDismissMonitor()
        dismissMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .keyDown]
        ) { event in
            guard let dismissEvent = FloatingPanelDismissEvent(event: event),
                  FloatingPanelDismissPolicy.shouldDismiss(for: dismissEvent)
            else {
                return
            }
            Task { @MainActor in
                onDismiss()
            }
        }
    }

    private func stopDismissMonitor() {
        if let dismissMonitor {
            NSEvent.removeMonitor(dismissMonitor)
            self.dismissMonitor = nil
        }
    }
}

private extension FloatingPanelDismissEvent {
    init?(event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown:
            self = .pointerDown
        case .keyDown:
            self = .keyDown(event.keyCode)
        default:
            return nil
        }
    }
}
