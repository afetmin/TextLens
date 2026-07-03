import AppKit
import Foundation
import PermissionFlow
import TextLensCore
@preconcurrency import Translation

@MainActor
final class AppModel: ObservableObject {
    @Published var settings: AppSettings
    @Published var statusMessage = ""
    @Published var activeResult: AssistantResult?
    @Published var apiKeyDraft = ""
    @Published var baseURLDraft = ""
    @Published var modelDraft = ""
    @Published var modelStatusMessage = ""
    @Published var accessibilityTrusted: Bool
    @Published var appleTranslationConfiguration: TranslationSession.Configuration?
    @Published private(set) var appleTranslationRequest: AppleTranslationRequest?
    @Published var appleLanguageDownloadConfiguration: TranslationSession.Configuration?
    @Published private(set) var appleLanguageDownloadRequest: AppleLanguageDownloadRequest?
    @Published private(set) var appleLanguageDownloadStatus: AppleLanguageDownloadStatus = .unknown

    private let configurationStore: AppConfigurationStore
    private let secretStore: SecretStoring
    private let permissionFlowController = PermissionFlow.makeController(
        configuration: PermissionFlowConfiguration(
            requiredAppURLs: AppModel.currentAppBundleURLs,
            promptForAccessibilityTrust: false,
            localeIdentifier: "zh-Hans"
        )
    )
    private let resultPanel = ResultPanelController()
    private let tipPanel = TipPanelController()
    private var monitor: GlobalSelectionMonitor?
    private var permissionRecoveryCoordinator = PermissionRecoveryCoordinator()
    private var permissionPollingTask: Task<Void, Never>?
    private var appleLanguageAvailabilityTask: Task<Void, Never>?
    private var appleTranslationConfigurationIdentity: AppleTranslationConfigurationIdentity?
    private var appleLanguageDownloadConfigurationIdentity: AppleTranslationConfigurationIdentity?
    private var pendingSnapshot: SelectionSnapshot?

    init(
        configurationStore: AppConfigurationStore = AppConfigurationStore(),
        secretStore: SecretStoring = UserDefaultsSecretStore()
    ) {
        self.configurationStore = configurationStore
        self.secretStore = secretStore
        let loadedSettings = configurationStore.loadSettings()
        self.settings = loadedSettings
        self.baseURLDraft = loadedSettings.providerConfig.baseURL.absoluteString
        self.modelDraft = loadedSettings.providerConfig.model
        self.apiKeyDraft = (try? secretStore.loadAPIKey()) ?? ""
        self.accessibilityTrusted = AccessibilitySelectionReader.isTrusted
        self.statusMessage = accessibilityTrusted
            ? "已准备读取选区"
            : "需要辅助功能权限"
        configureMonitor()
    }

    func setPopupEnabled(_ enabled: Bool) {
        settings.selectionPopupEnabled = enabled
        saveSettings()
        configureMonitor()
    }

    func setTargetLanguage(_ language: String) {
        guard settings.targetLanguage != language else { return }
        settings.targetLanguage = language
        appleLanguageDownloadRequest = nil
        appleLanguageDownloadConfiguration = nil
        appleLanguageDownloadConfigurationIdentity = nil
        saveSettings()
        refreshSelectedAppleLanguageAvailability()
    }

    func setTranslationEngine(_ engine: TranslationEngine) {
        guard settings.translationEngine != engine else { return }
        settings.translationEngine = engine
        if engine != .appleTranslation {
            appleLanguageDownloadRequest = nil
            appleLanguageDownloadConfiguration = nil
            appleLanguageDownloadConfigurationIdentity = nil
        }
        saveSettings()
        refreshSelectedAppleLanguageAvailability()
    }

    func saveSettingsFromDrafts() {
        if let url = URL(string: baseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)) {
            settings.providerConfig.baseURL = url
        }
        let model = modelDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        if !model.isEmpty {
            settings.providerConfig.model = model
        }
        saveSettings()
        configureMonitor()
    }

    func saveSettings() {
        configurationStore.saveSettings(settings)
        baseURLDraft = settings.providerConfig.baseURL.absoluteString
        modelDraft = settings.providerConfig.model
    }

    func prepareSelectedAppleLanguage() {
        guard let start = AppleTranslationRuntimePlan.startLanguageDownload(
            translationEngine: settings.translationEngine,
            currentStatus: appleLanguageDownloadStatus,
            targetLanguage: settings.targetLanguage,
            requestID: UUID(),
            currentConfiguration: appleLanguageDownloadConfigurationIdentity
        ) else {
            return
        }

        appleLanguageAvailabilityTask?.cancel()
        appleLanguageDownloadRequest = start.request
        appleLanguageDownloadStatus = start.status
        appleLanguageDownloadConfiguration = makeAppleTranslationConfiguration(start.configuration)
        appleLanguageDownloadConfigurationIdentity = start.configuration.identity
    }

    func currentAppleLanguageDownloadRequest() -> AppleLanguageDownloadRequest? {
        appleLanguageDownloadRequest
    }

    func completeAppleLanguageDownload(
        _ request: AppleLanguageDownloadRequest,
        verifiedStatus: AppleLanguageDownloadStatus
    ) {
        guard appleLanguageDownloadRequest?.id == request.id else { return }
        appleLanguageDownloadRequest = nil
        appleLanguageDownloadStatus = AppleLanguageDownloadCompletionPolicy.statusAfterPreparation(
            verifiedStatus: verifiedStatus
        )
    }

    func failAppleLanguageDownload(_ request: AppleLanguageDownloadRequest, error _: Error) {
        guard appleLanguageDownloadRequest?.id == request.id else { return }
        appleLanguageDownloadRequest = nil
        appleLanguageDownloadStatus = AppleTranslationRuntimePlan.statusAfterLanguageDownloadFailure()
    }

    func refreshSelectedAppleLanguageAvailability() {
        appleLanguageAvailabilityTask?.cancel()

        let refresh = AppleTranslationRuntimePlan.refreshLanguageAvailability(
            translationEngine: settings.translationEngine,
            targetLanguage: settings.targetLanguage,
            activeDownloadRequest: appleLanguageDownloadRequest
        )
        appleLanguageDownloadStatus = refresh.status
        guard let query = refresh.query else { return }

        appleLanguageAvailabilityTask = Task { [weak self] in
            let status = await AppleTranslationService().downloadStatus(
                sourceLanguage: query.sourceLanguage,
                targetLanguage: query.targetLanguage
            )
            guard !Task.isCancelled else { return }

            await MainActor.run {
                guard let self else { return }
                guard self.settings.translationEngine == .appleTranslation,
                      self.settings.targetLanguage == query.targetLanguage,
                      self.appleLanguageDownloadRequest?.targetLanguage != query.targetLanguage
                else {
                    return
                }
                self.appleLanguageDownloadStatus = status
            }
        }
    }

    func saveAPIKey() {
        do {
            let key = apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
            if key.isEmpty {
                try secretStore.deleteAPIKey()
                modelStatusMessage = "已清除 API Key"
            } else {
                try secretStore.saveAPIKey(key)
                modelStatusMessage = "已保存 API Key"
            }
        } catch {
            modelStatusMessage = "保存失败：\(error.localizedDescription)"
        }
    }

    func requestAccessibilityPermission() {
        let plan = PermissionAuthorizationPlan.accessibility
        if plan.opensGuidedSettings {
            permissionFlowController.authorize(
                pane: .accessibility,
                suggestedAppURLs: Self.currentAppBundleURLs,
                sourceFrameInScreen: Self.currentPointerSourceFrame()
            )
        }
        permissionRecoveryCoordinator.recordPermissionPrompt()
        refreshAccessibilityTrust()
        if accessibilityTrusted {
            statusMessage = "已获得辅助功能权限"
            configureMonitor()
        } else {
            statusMessage = "请在系统设置中授权"
            if plan.startsRecoveryPolling {
                startPermissionPolling()
            }
        }
    }

    func closePanel() {
        tipPanel.close()
        resultPanel.close()
        monitor?.resetSelectionHistory()
    }

    func copyActiveResult() {
        guard let activeResult else { return }
        let text = [
            activeResult.snapshot.text,
            activeResult.translation.map { "翻译：\($0)" },
            activeResult.explanation.map { "解释：\($0)" }
        ]
        .compactMap { $0 }
        .joined(separator: "\n\n")

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        statusMessage = "已复制"
    }

    func openSettings() {
        refreshAccessibilityTrust()
        SettingsWindowController.shared.show(model: self)
    }

    func refreshAccessibilityTrust() {
        accessibilityTrusted = AccessibilitySelectionReader.isTrusted
    }

    func testModelConnection() {
        modelStatusMessage = "正在测试连接"
        Task {
            do {
                let client = try makeLLMClient()
                _ = try await client.translate(text: "hello", targetLanguage: settings.targetLanguage)
                modelStatusMessage = "连接可用"
            } catch {
                modelStatusMessage = "连接失败：\(error.localizedDescription)"
            }
        }
    }

    func performSelectionAction(_ action: SelectionAction) {
        guard let snapshot = pendingSnapshot else { return }
        let sourceFrame = tipPanel.visibleFrame

        tipPanel.close(animated: false)

        let update = SelectionAssistantFlow.start(
            snapshot: snapshot,
            action: action,
            targetLanguage: settings.targetLanguage,
            translationEngine: settings.translationEngine,
            appleRequestID: UUID()
        )
        guard let result = update.result else { return }

        activeResult = result
        resultPanel.show(model: self, near: snapshot.anchorPoint, sourceFrame: sourceFrame)
        performAssistantCommands(update.commands)
    }

    private func configureMonitor() {
        if settings.selectionPopupEnabled {
            refreshAccessibilityTrust()
            if monitor == nil {
                let gate = SelectionEventGate(debounceInterval: 0.45, maximumTextLength: 4_000)
                monitor = GlobalSelectionMonitor(
                    reader: AccessibilitySelectionReader(),
                    gate: gate,
                    onSnapshot: { [weak self] snapshot in
                        self?.handleSelection(snapshot)
                    },
                    onStatus: { [weak self] status in
                        self?.statusMessage = status
                    }
                )
            }
            if monitor?.start() == false {
                permissionRecoveryCoordinator.recordPermissionPrompt()
                startPermissionPolling()
            }
        } else {
            monitor?.stop()
            tipPanel.close()
            resultPanel.close()
            statusMessage = "划词自动弹出已关闭"
        }
    }

    private func startPermissionPolling() {
        permissionPollingTask?.cancel()
        permissionPollingTask = Task { @MainActor in
            for _ in 0..<90 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                refreshAccessibilityTrust()
                if permissionRecoveryCoordinator.observeTrustedState(accessibilityTrusted) {
                    statusMessage = "已获得辅助功能权限，划词监听已开启"
                    configureMonitor()
                    return
                }
            }
            refreshAccessibilityTrust()
            statusMessage = accessibilityTrusted
                ? "已获得辅助功能权限"
                : "仍未检测到辅助功能权限"
        }
    }

    private func handleSelection(_ snapshot: SelectionSnapshot) {
        pendingSnapshot = snapshot
        activeResult = nil
        resultPanel.close()
        tipPanel.show(model: self, near: snapshot.anchorPoint)
    }

    private func performAssistantCommands(_ commands: [SelectionAssistantCommand]) {
        for command in commands {
            switch command {
            case .requestAppleTranslation(let request):
                requestAppleTranslation(request)
            case .requestLLMTranslation(let request):
                loadLLMTranslation(request)
            case .requestLLMExplanation(let request):
                loadExplanation(request)
            }
        }
    }

    private func requestAppleTranslation(_ request: AppleTranslationRequest) {
        appleTranslationRequest = request
        let update = AppleTranslationRuntimePlan.translationConfiguration(
            for: request,
            currentConfiguration: appleTranslationConfigurationIdentity
        )
        appleTranslationConfiguration = makeAppleTranslationConfiguration(update)
        appleTranslationConfigurationIdentity = update.identity
    }

    private func makeAppleTranslationConfiguration(
        _ update: AppleTranslationConfigurationUpdate
    ) -> TranslationSession.Configuration {
        let source = update.identity.sourceLanguage.map(Locale.Language.init(identifier:))
        let target = Locale.Language(identifier: update.identity.targetLanguage)
        var configuration: TranslationSession.Configuration
        if #available(macOS 26.4, *) {
            configuration = TranslationSession.Configuration(
                source: source,
                target: target,
                preferredStrategy: .lowLatency
            )
        } else {
            configuration = TranslationSession.Configuration(source: source, target: target)
        }
        if update.invalidatesExistingConfiguration {
            configuration.invalidate()
        }
        return configuration
    }

    func currentAppleTranslationRequest() -> AppleTranslationRequest? {
        appleTranslationRequest
    }

    func completeAppleTranslation(_ request: AppleTranslationRequest, translation: String) {
        guard appleTranslationRequest?.id == request.id else { return }
        appleTranslationRequest = nil
        guard let result = SelectionAssistantFlow.completeAppleTranslation(
            request,
            translation: translation,
            currentResult: activeResult
        ) else {
            return
        }
        applyAssistantResult(result, near: request.snapshot)
    }

    func fallBackFromAppleTranslation(_ request: AppleTranslationRequest) {
        guard appleTranslationRequest?.id == request.id else { return }
        appleTranslationRequest = nil
        guard let update = SelectionAssistantFlow.fallBackFromAppleTranslation(
            request,
            currentResult: activeResult
        ) else {
            return
        }
        if let result = update.result {
            applyAssistantResult(result, near: request.snapshot)
        }
        performAssistantCommands(update.commands)
    }

    private func loadLLMTranslation(_ request: LLMTranslationRequest) {
        Task {
            do {
                let client = try makeLLMClient()
                let translation = try await client.translate(text: request.text, targetLanguage: request.targetLanguage)
                guard let result = SelectionAssistantFlow.completeLLMTranslation(
                    request,
                    translation: translation,
                    currentResult: activeResult
                ) else {
                    return
                }
                applyAssistantResult(result, near: request.snapshot)
            } catch {
                guard let result = SelectionAssistantFlow.failTranslation(
                    request,
                    failure: resultFailure(for: error),
                    currentResult: activeResult
                ) else {
                    return
                }
                applyAssistantResult(result, near: request.snapshot)
            }
        }
    }

    private func loadExplanation(_ request: LLMExplanationRequest) {
        Task {
            do {
                let client = try makeLLMClient()
                let explanation = try await client.explain(text: request.text, targetLanguage: request.targetLanguage)
                guard let result = SelectionAssistantFlow.completeExplanation(
                    request,
                    explanation: explanation,
                    currentResult: activeResult
                ) else {
                    return
                }
                applyAssistantResult(result, near: request.snapshot)
            } catch {
                guard let result = SelectionAssistantFlow.failExplanation(
                    request,
                    failure: resultFailure(for: error),
                    currentResult: activeResult
                ) else {
                    return
                }
                applyAssistantResult(result, near: request.snapshot)
            }
        }
    }

    private func applyAssistantResult(_ result: AssistantResult, near snapshot: SelectionSnapshot) {
        activeResult = result
        resultPanel.updateLayout(model: self, near: snapshot.anchorPoint)
    }

    private func makeLLMClient() throws -> OpenAICompatibleClient {
        guard let apiKey = try secretStore.loadAPIKey(), !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppModelError.missingAPIKey
        }
        return OpenAICompatibleClient(config: settings.providerConfig, apiKey: apiKey)
    }

    private static var currentAppBundleURLs: [URL] {
        let bundleURL = Bundle.main.bundleURL.standardizedFileURL
        return bundleURL.pathExtension.lowercased() == "app" ? [bundleURL] : []
    }

    private static func currentPointerSourceFrame() -> CGRect {
        let mouse = NSEvent.mouseLocation
        return CGRect(x: mouse.x - 18, y: mouse.y - 18, width: 36, height: 36)
    }
}

private func resultFailure(for error: Error) -> AssistantResultFailure {
    if let appModelError = error as? AppModelError, appModelError == .missingAPIKey {
        return .missingAPIKey
    }
    return .providerFailure(message: error.localizedDescription)
}

enum AppModelError: LocalizedError, Equatable {
    case missingAPIKey

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "请先在设置里配置大语言模型 API Key"
        }
    }
}
