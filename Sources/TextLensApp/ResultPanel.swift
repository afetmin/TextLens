import AppKit
import TextLensCore
@preconcurrency import Translation
import SwiftUI

@MainActor
final class ResultPanelController {
    private let host = FloatingPanelHost(initialSize: NSSize(width: 320, height: 220))
    private let layoutRules = FloatingPanelLayoutRules(
        screenInset: 12,
        anchorGap: 12,
        horizontalOffset: 12,
        preferredPlacement: .belowAnchor
    )

    func show(model: AppModel, near anchor: CGPoint, sourceFrame: NSRect? = nil) {
        let panel = host.panel {
            NSHostingView(
                rootView: ResultPanelView()
                    .environmentObject(model)
            )
        }

        let geometry = geometry(for: model.activeResult, near: anchor)
        if panel.isVisible {
            animate(panel, to: geometry.frame, duration: 0.16)
        } else {
            expandIn(panel, from: sourceFrame, to: geometry, near: anchor)
        }
        startDismissMonitor(model: model)
    }

    func updateLayout(model: AppModel, near anchor: CGPoint) {
        guard let panel = host.visiblePanel else { return }
        let geometry = geometry(for: model.activeResult, near: anchor)
        animate(panel, to: geometry.frame, duration: 0.18)
    }

    func close() {
        host.close(duration: 0.12)
    }

    private func geometry(for result: AssistantResult?, near anchor: CGPoint) -> FloatingPanelLayoutResult {
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        return layoutRules.layout(
            preferredSize: preferredSize(for: result, visibleFrame: visibleFrame),
            near: anchor,
            in: visibleFrame
        )
    }

    private func preferredSize(for result: AssistantResult?, visibleFrame: CGRect) -> NSSize {
        guard let result else { return NSSize(width: 340, height: 170) }
        let width = result.failure != nil || result.isLoadingTranslation || result.isLoadingExplanation
            ? CGFloat(340)
            : CGFloat(430)
        if result.failure != nil {
            return NSSize(width: width, height: 154)
        }
        if result.isLoadingTranslation || result.isLoadingExplanation {
            return NSSize(width: width, height: 142)
        }

        let output = activeOutput(for: result)
        let contentWidth = width - 24
        let bodyHeight = measuredTextHeight(
            output.isEmpty ? "未返回内容" : output,
            font: .systemFont(ofSize: 14, weight: .regular),
            width: contentWidth,
            lineSpacing: 3
        )
        let chromeHeight: CGFloat = 36 + 16 + 10 + 12
        let desiredHeight = chromeHeight + bodyHeight
        let maximumHeight = min(max(visibleFrame.height - 24, 180), 460)

        return NSSize(
            width: width,
            height: min(max(desiredHeight, 170), maximumHeight)
        )
    }

    private func activeOutput(for result: AssistantResult) -> String {
        let text = result.showsTranslation ? result.translation : result.explanation
        return text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private func measuredTextHeight(
        _ text: String,
        font: NSFont,
        width: CGFloat,
        lineSpacing: CGFloat
    ) -> CGFloat {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineBreakMode = .byWordWrapping
        paragraphStyle.lineSpacing = lineSpacing
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: max(width, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]
        )

        return ceil(rect.height)
    }

    private func expandIn(
        _ panel: NSPanel,
        from sourceFrame: NSRect?,
        to geometry: FloatingPanelLayoutResult,
        near anchor: CGPoint
    ) {
        let targetFrame = geometry.frame
        let initialFrame = sourceFrame ?? seedFrame(for: geometry, near: anchor)
        panel.alphaValue = reduceMotion ? 1 : 0.88
        panel.setFrame(initialFrame, display: true)
        panel.orderFrontRegardless()
        animate(panel, to: targetFrame, duration: 0.20)
    }

    private func seedFrame(for geometry: FloatingPanelLayoutResult, near anchor: CGPoint) -> NSRect {
        let targetFrame = geometry.frame
        let seedSize = NSSize(
            width: min(76, targetFrame.width),
            height: min(34, targetFrame.height)
        )
        let originY: CGFloat
        switch geometry.placement {
        case .aboveAnchor:
            originY = targetFrame.minY
        case .belowAnchor:
            originY = targetFrame.maxY - seedSize.height
        }

        return NSRect(
            x: targetFrame.minX,
            y: originY,
            width: seedSize.width,
            height: seedSize.height
        )
    }

    private func animate(_ panel: NSPanel, to frame: NSRect, duration: TimeInterval) {
        guard !reduceMotion else {
            panel.setFrame(frame, display: true)
            panel.alphaValue = 1
            return
        }

        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.22, 1, 0.36, 1)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    private var reduceMotion: Bool {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    private func startDismissMonitor(model: AppModel) {
        host.startDismissMonitor { [weak model] in
            model?.closePanel()
        }
    }
}

struct ResultPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 10)
                .padding(.top, 8)
                .padding(.bottom, 6)

            if let result = model.activeResult {
                VStack(alignment: .leading, spacing: 10) {
                    Text(result.snapshot.text)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .textSelection(.enabled)

                    content(for: result)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                )
        }
        .scaleEffect(isPresented || reduceMotion ? 1 : 0.98, anchor: .topLeading)
        .opacity(isPresented || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .smooth(duration: 0.14), value: isPresented)
        .onAppear {
            isPresented = true
        }
        .translationTask(model.appleTranslationConfiguration) { session in
            guard let request = model.currentAppleTranslationRequest() else { return }
            do {
                let translation = try await AppleTranslationService().translate(request, using: session)
                model.completeAppleTranslation(request, translation: translation)
            } catch {
                model.fallBackFromAppleTranslation(request)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: activeIconName)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(activeTitle)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
            if let sourcePresentation = activeTranslationSourcePresentation {
                Text(sourcePresentation.label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .frame(height: 16)
                    .background {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(Color.black.opacity(0.035))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    }
                    .accessibilityLabel(sourcePresentation.accessibilityLabel)
                    .help(sourcePresentation.helpText)
            }
            Spacer()
            Button(action: model.copyActiveResult) {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(PanelIconButtonStyle())
            .help("复制")

            Button(action: model.closePanel) {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(PanelIconButtonStyle())
            .help("关闭")
        }
    }

    private var activeTitle: String {
        guard let result = model.activeResult else { return "划词" }
        if result.showsTranslation { return "翻译" }
        if result.showsExplanation { return "解释" }
        return "划词"
    }

    private var activeIconName: String {
        guard let result = model.activeResult else { return "text.magnifyingglass" }
        if result.showsTranslation { return "translate" }
        if result.showsExplanation { return "book.closed" }
        return "text.magnifyingglass"
    }

    private var activeTranslationSourcePresentation: TranslationSourcePresentation? {
        guard let result = model.activeResult,
              result.showsTranslation,
              !result.isLoadingTranslation,
              result.failure == nil,
              let source = result.translationSource else {
            return nil
        }
        return TranslationSourcePresentation.make(for: source)
    }

    private func content(for result: AssistantResult) -> some View {
        let isLoading = result.isLoadingTranslation || result.isLoadingExplanation
        let text = result.showsTranslation ? result.translation : result.explanation

        return Group {
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                    Text(result.showsTranslation ? "正在翻译" : "正在解释")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            } else if let failure = result.failure {
                failureView(failure, action: activeAction(for: result))
            } else {
                let output = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if output.isEmpty {
                    Text("未返回内容")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                } else {
                    ScrollView {
                        Text(output)
                            .font(.system(size: 14, weight: .regular))
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func failureView(_ failure: AssistantResultFailure, action: SelectionAction) -> some View {
        let presentation = AssistantResultFailurePresentation.make(for: failure, action: action)

        return HStack(alignment: .top, spacing: 9) {
            Image(systemName: presentation.systemImageName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(tintColor(for: presentation))
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(presentation.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(presentation.message)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 6)

            if presentation.shouldOfferSettings {
                Button(action: model.openSettings) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(PanelIconButtonStyle())
                .help("打开设置")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.black.opacity(0.035))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.06), lineWidth: 1)
                )
        }
    }

    private func activeAction(for result: AssistantResult) -> SelectionAction {
        result.showsTranslation ? .translate : .explain
    }

    private func tintColor(for presentation: AssistantResultFailurePresentation) -> Color {
        switch presentation.tone {
        case .setup:
            return .accentColor
        case .warning:
            return .orange
        }
    }
}

private struct PanelIconButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        PanelIconButton(configuration: configuration, reduceMotion: reduceMotion)
    }

    private struct PanelIconButton: View {
        let configuration: ButtonStyle.Configuration
        let reduceMotion: Bool
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .frame(width: 22, height: 22)
                .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .background {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.primary.opacity(backgroundOpacity))
                }
                .scaleEffect(scale)
                .animation(reduceMotion ? nil : .smooth(duration: 0.10), value: isHovering)
                .animation(reduceMotion ? nil : .smooth(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundOpacity: Double {
            if configuration.isPressed { return 0.14 }
            if isHovering { return 0.08 }
            return 0
        }

        private var scale: CGFloat {
            guard !reduceMotion else { return 1 }
            if configuration.isPressed { return 0.94 }
            if isHovering { return 1.03 }
            return 1
        }
    }
}

@MainActor
final class TipPanelController {
    private let host = FloatingPanelHost(initialSize: NSSize(width: 64, height: 30))
    private let layoutRules = FloatingPanelLayoutRules(
        screenInset: 8,
        anchorGap: 9,
        horizontalOffset: 10,
        preferredPlacement: .aboveAnchor
    )

    var visibleFrame: NSRect? {
        host.visibleFrame
    }

    func show(model: AppModel, near anchor: CGPoint) {
        let panel = host.panel {
            NSHostingView(
                rootView: TipPanelView()
                    .environmentObject(model)
            )
        }

        let size = NSSize(width: 64, height: 30)
        let screen = NSScreen.screens.first(where: { $0.frame.contains(anchor) }) ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let frame = layoutRules.layout(
            preferredSize: size,
            near: anchor,
            in: visibleFrame
        ).frame
        panel.setFrame(frame, display: true)
        host.fadeIn(duration: 0.14)
        startDismissMonitor(model: model)
    }

    func close(animated: Bool = true) {
        host.close(animated: animated, duration: 0.10)
    }

    private func startDismissMonitor(model: AppModel) {
        host.startDismissMonitor { [weak model] in
            model?.closePanel()
        }
    }
}

struct TipPanelView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPresented = false

    var body: some View {
        HStack(spacing: 3) {
            ForEach(SelectionAction.defaultTipActions, id: \.self) { action in
                actionButton(action, systemImage: iconName(for: action), help: helpText(for: action))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(width: 64, height: 30)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Color.white)
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(Color.black.opacity(0.10), lineWidth: 1)
                )
        }
        .scaleEffect(isPresented || reduceMotion ? 1 : 0.94, anchor: .topLeading)
        .opacity(isPresented || reduceMotion ? 1 : 0)
        .animation(reduceMotion ? nil : .smooth(duration: 0.13), value: isPresented)
        .onAppear {
            isPresented = true
        }
    }

    private func actionButton(_ action: SelectionAction, systemImage: String, help: String) -> some View {
        Button {
            model.performSelectionAction(action)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .regular))
                .foregroundStyle(.primary)
                .frame(width: 24, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(TipActionButtonStyle())
        .help(help)
    }

    private func iconName(for action: SelectionAction) -> String {
        switch action {
        case .translate:
            "translate"
        case .explain:
            "book.closed"
        }
    }

    private func helpText(for action: SelectionAction) -> String {
        switch action {
        case .translate:
            "翻译"
        case .explain:
            "解释"
        }
    }
}

private struct TipActionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        TipActionButton(configuration: configuration, reduceMotion: reduceMotion)
    }

    private struct TipActionButton: View {
        let configuration: ButtonStyle.Configuration
        let reduceMotion: Bool
        @State private var isHovering = false

        var body: some View {
            configuration.label
                .background {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(backgroundOpacity))
                }
                .scaleEffect(scale)
                .animation(reduceMotion ? nil : .smooth(duration: 0.12), value: isHovering)
                .animation(reduceMotion ? nil : .smooth(duration: 0.08), value: configuration.isPressed)
                .onHover { isHovering = $0 }
        }

        private var backgroundOpacity: Double {
            if configuration.isPressed { return 0.16 }
            if isHovering { return 0.08 }
            return 0
        }

        private var scale: CGFloat {
            guard !reduceMotion else { return 1 }
            if configuration.isPressed { return 0.94 }
            if isHovering { return 1.02 }
            return 1
        }
    }
}
