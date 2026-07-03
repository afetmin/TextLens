import Foundation

public struct AssistantResult: Equatable, Sendable {
    public var snapshot: SelectionSnapshot
    public var showsTranslation: Bool
    public var showsExplanation: Bool
    public var translation: String?
    public var translationSource: TranslationResultSource?
    public var explanation: String?
    public var failure: AssistantResultFailure?
    public var isLoadingTranslation: Bool
    public var isLoadingExplanation: Bool

    public init(
        snapshot: SelectionSnapshot,
        showsTranslation: Bool,
        showsExplanation: Bool,
        translation: String?,
        translationSource: TranslationResultSource?,
        explanation: String?,
        failure: AssistantResultFailure?,
        isLoadingTranslation: Bool,
        isLoadingExplanation: Bool
    ) {
        self.snapshot = snapshot
        self.showsTranslation = showsTranslation
        self.showsExplanation = showsExplanation
        self.translation = translation
        self.translationSource = translationSource
        self.explanation = explanation
        self.failure = failure
        self.isLoadingTranslation = isLoadingTranslation
        self.isLoadingExplanation = isLoadingExplanation
    }
}

public struct AppleTranslationRequest: Equatable, Sendable {
    public var id: UUID
    public var snapshot: SelectionSnapshot
    public var text: String
    public var sourceLanguage: String?
    public var targetLanguage: String

    public init(
        id: UUID,
        snapshot: SelectionSnapshot,
        text: String,
        sourceLanguage: String?,
        targetLanguage: String
    ) {
        self.id = id
        self.snapshot = snapshot
        self.text = text
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public struct LLMTranslationRequest: Equatable, Sendable {
    public var snapshot: SelectionSnapshot
    public var text: String
    public var targetLanguage: String
    public var source: TranslationResultSource

    public init(
        snapshot: SelectionSnapshot,
        text: String,
        targetLanguage: String,
        source: TranslationResultSource
    ) {
        self.snapshot = snapshot
        self.text = text
        self.targetLanguage = targetLanguage
        self.source = source
    }
}

public struct LLMExplanationRequest: Equatable, Sendable {
    public var snapshot: SelectionSnapshot
    public var text: String
    public var targetLanguage: String

    public init(snapshot: SelectionSnapshot, text: String, targetLanguage: String) {
        self.snapshot = snapshot
        self.text = text
        self.targetLanguage = targetLanguage
    }
}

public enum SelectionAssistantCommand: Equatable, Sendable {
    case requestAppleTranslation(AppleTranslationRequest)
    case requestLLMTranslation(LLMTranslationRequest)
    case requestLLMExplanation(LLMExplanationRequest)
}

public struct SelectionAssistantFlowUpdate: Equatable, Sendable {
    public var result: AssistantResult?
    public var commands: [SelectionAssistantCommand]

    public init(result: AssistantResult?, commands: [SelectionAssistantCommand]) {
        self.result = result
        self.commands = commands
    }
}

public enum SelectionAssistantFlow {
    public static func start(
        snapshot: SelectionSnapshot,
        action: SelectionAction,
        targetLanguage: String,
        translationEngine: TranslationEngine,
        appleRequestID: UUID = UUID()
    ) -> SelectionAssistantFlowUpdate {
        let plan = SelectionActionPlan.plan(for: action)
        guard plan.showsResultPanel else {
            return SelectionAssistantFlowUpdate(result: nil, commands: [])
        }

        var result = AssistantResult(
            snapshot: snapshot,
            showsTranslation: plan.loadsTranslation,
            showsExplanation: plan.loadsExplanation,
            translation: nil,
            translationSource: nil,
            explanation: nil,
            failure: nil,
            isLoadingTranslation: plan.loadsTranslation,
            isLoadingExplanation: plan.loadsExplanation
        )
        var commands: [SelectionAssistantCommand] = []

        if plan.loadsTranslation {
            switch TranslationRequestPlan.make(text: snapshot.text, targetLanguage: targetLanguage) {
            case .useOriginalText:
                result.translation = snapshot.text
                result.translationSource = .originalText
                result.isLoadingTranslation = false
            case .translate(let sourceLanguage):
                switch translationEngine {
                case .appleTranslation:
                    let request = AppleTranslationRequest(
                        id: appleRequestID,
                        snapshot: snapshot,
                        text: snapshot.text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage
                    )
                    commands.append(.requestAppleTranslation(request))
                case .openAICompatible:
                    commands.append(
                        .requestLLMTranslation(
                            LLMTranslationRequest(
                                snapshot: snapshot,
                                text: snapshot.text,
                                targetLanguage: targetLanguage,
                                source: .openAICompatible
                            )
                        )
                    )
                }
            }
        }

        if plan.loadsExplanation {
            commands.append(
                .requestLLMExplanation(
                    LLMExplanationRequest(
                        snapshot: snapshot,
                        text: snapshot.text,
                        targetLanguage: targetLanguage
                    )
                )
            )
        }

        return SelectionAssistantFlowUpdate(result: result, commands: commands)
    }

    public static func completeAppleTranslation(
        _ request: AppleTranslationRequest,
        translation: String,
        currentResult: AssistantResult?
    ) -> AssistantResult? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.translation = translation
        result.translationSource = .appleTranslation
        result.isLoadingTranslation = false
        return result
    }

    public static func fallBackFromAppleTranslation(
        _ request: AppleTranslationRequest,
        currentResult: AssistantResult?
    ) -> SelectionAssistantFlowUpdate? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.translation = nil
        result.translationSource = nil
        result.isLoadingTranslation = true
        return SelectionAssistantFlowUpdate(
            result: result,
            commands: [
                .requestLLMTranslation(
                    LLMTranslationRequest(
                        snapshot: request.snapshot,
                        text: request.text,
                        targetLanguage: request.targetLanguage,
                        source: .openAICompatibleAfterAppleFallback
                    )
                )
            ]
        )
    }

    public static func completeLLMTranslation(
        _ request: LLMTranslationRequest,
        translation: String,
        currentResult: AssistantResult?
    ) -> AssistantResult? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.translation = translation
        result.translationSource = request.source
        result.isLoadingTranslation = false
        return result
    }

    public static func failTranslation(
        _ request: LLMTranslationRequest,
        failure: AssistantResultFailure,
        currentResult: AssistantResult?
    ) -> AssistantResult? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.isLoadingTranslation = false
        result.failure = failure
        return result
    }

    public static func completeExplanation(
        _ request: LLMExplanationRequest,
        explanation: String,
        currentResult: AssistantResult?
    ) -> AssistantResult? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.explanation = explanation
        result.isLoadingExplanation = false
        return result
    }

    public static func failExplanation(
        _ request: LLMExplanationRequest,
        failure: AssistantResultFailure,
        currentResult: AssistantResult?
    ) -> AssistantResult? {
        guard var result = currentResult, result.snapshot == request.snapshot else { return nil }
        result.isLoadingExplanation = false
        result.failure = failure
        return result
    }
}
