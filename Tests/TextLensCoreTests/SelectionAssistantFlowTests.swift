import CoreGraphics
import XCTest
@testable import TextLensCore

final class SelectionAssistantFlowTests: XCTestCase {
    func testTranslateUsesOriginalTextWhenSourceAlreadyMatchesTarget() {
        let update = SelectionAssistantFlow.start(
            snapshot: snapshot(text: "hello"),
            action: .translate,
            targetLanguage: "en",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )

        XCTAssertEqual(update.commands, [])
        XCTAssertEqual(update.result?.translation, "hello")
        XCTAssertEqual(update.result?.translationSource, .originalText)
        XCTAssertEqual(update.result?.isLoadingTranslation, false)
        XCTAssertEqual(update.result?.isLoadingExplanation, false)
    }

    func testTranslateWithAppleEngineRequestsAppleTranslation() {
        let selectedText = snapshot(text: "hello")

        let update = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )

        XCTAssertEqual(update.result?.translation, nil)
        XCTAssertEqual(update.result?.translationSource, nil)
        XCTAssertEqual(update.result?.isLoadingTranslation, true)
        XCTAssertEqual(
            update.commands,
            [
                .requestAppleTranslation(
                    AppleTranslationRequest(
                        id: fixedRequestID,
                        snapshot: selectedText,
                        text: "hello",
                        sourceLanguage: "en",
                        targetLanguage: "zh-Hans"
                    )
                )
            ]
        )
    }

    func testTranslateWithOpenAIEngineRequestsLLMTranslation() {
        let selectedText = snapshot(text: "hello")

        let update = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .openAICompatible,
            appleRequestID: fixedRequestID
        )

        XCTAssertEqual(
            update.commands,
            [
                .requestLLMTranslation(
                    LLMTranslationRequest(
                        snapshot: selectedText,
                        text: "hello",
                        targetLanguage: "zh-Hans",
                        source: .openAICompatible
                    )
                )
            ]
        )
    }

    func testExplainRequestsLLMExplanationOnly() {
        let selectedText = snapshot(text: "opaque wording")

        let update = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .explain,
            targetLanguage: "zh-Hans",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )

        XCTAssertEqual(update.result?.showsTranslation, false)
        XCTAssertEqual(update.result?.showsExplanation, true)
        XCTAssertEqual(update.result?.isLoadingTranslation, false)
        XCTAssertEqual(update.result?.isLoadingExplanation, true)
        XCTAssertEqual(
            update.commands,
            [
                .requestLLMExplanation(
                    LLMExplanationRequest(
                        snapshot: selectedText,
                        text: "opaque wording",
                        targetLanguage: "zh-Hans"
                    )
                )
            ]
        )
    }

    func testCompletesAppleTranslationIntoResult() throws {
        let selectedText = snapshot(text: "hello")
        let started = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )
        let request = try XCTUnwrap(started.appleTranslationRequest)

        let result = SelectionAssistantFlow.completeAppleTranslation(
            request,
            translation: "你好",
            currentResult: started.result
        )

        XCTAssertEqual(result?.translation, "你好")
        XCTAssertEqual(result?.translationSource, .appleTranslation)
        XCTAssertEqual(result?.isLoadingTranslation, false)
    }

    func testAppleFallbackKeepsLoadingAndRequestsLLMWithFallbackSource() throws {
        let selectedText = snapshot(text: "hello")
        let started = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )
        let request = try XCTUnwrap(started.appleTranslationRequest)

        let update = try XCTUnwrap(
            SelectionAssistantFlow.fallBackFromAppleTranslation(
                request,
                currentResult: started.result
            )
        )

        XCTAssertEqual(update.result?.translation, nil)
        XCTAssertEqual(update.result?.translationSource, nil)
        XCTAssertEqual(update.result?.isLoadingTranslation, true)
        XCTAssertEqual(
            update.commands,
            [
                .requestLLMTranslation(
                    LLMTranslationRequest(
                        snapshot: selectedText,
                        text: "hello",
                        targetLanguage: "zh-Hans",
                        source: .openAICompatibleAfterAppleFallback
                    )
                )
            ]
        )
    }

    func testCompletesLLMTranslationWithRequestedSource() throws {
        let selectedText = snapshot(text: "hello")
        let started = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .openAICompatible,
            appleRequestID: fixedRequestID
        )
        let request = try XCTUnwrap(started.llmTranslationRequest)

        let result = SelectionAssistantFlow.completeLLMTranslation(
            request,
            translation: "你好",
            currentResult: started.result
        )

        XCTAssertEqual(result?.translation, "你好")
        XCTAssertEqual(result?.translationSource, .openAICompatible)
        XCTAssertEqual(result?.isLoadingTranslation, false)
    }

    func testTranslationFailureStopsLoadingAndStoresFailure() throws {
        let selectedText = snapshot(text: "hello")
        let started = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .openAICompatible,
            appleRequestID: fixedRequestID
        )
        let request = try XCTUnwrap(started.llmTranslationRequest)

        let result = SelectionAssistantFlow.failTranslation(
            request,
            failure: .missingAPIKey,
            currentResult: started.result
        )

        XCTAssertEqual(result?.failure, .missingAPIKey)
        XCTAssertEqual(result?.isLoadingTranslation, false)
    }

    func testCompletesExplanationIntoResult() throws {
        let selectedText = snapshot(text: "opaque wording")
        let started = SelectionAssistantFlow.start(
            snapshot: selectedText,
            action: .explain,
            targetLanguage: "zh-Hans",
            translationEngine: .appleTranslation,
            appleRequestID: fixedRequestID
        )
        let request = try XCTUnwrap(started.llmExplanationRequest)

        let result = SelectionAssistantFlow.completeExplanation(
            request,
            explanation: "说明",
            currentResult: started.result
        )

        XCTAssertEqual(result?.explanation, "说明")
        XCTAssertEqual(result?.isLoadingExplanation, false)
    }

    func testIgnoresStaleResultUpdates() {
        let selectedText = snapshot(text: "hello")
        let staleText = snapshot(text: "bonjour")
        let started = SelectionAssistantFlow.start(
            snapshot: staleText,
            action: .translate,
            targetLanguage: "zh-Hans",
            translationEngine: .openAICompatible,
            appleRequestID: fixedRequestID
        )
        let request = LLMTranslationRequest(
            snapshot: selectedText,
            text: "hello",
            targetLanguage: "zh-Hans",
            source: .openAICompatible
        )

        let result = SelectionAssistantFlow.completeLLMTranslation(
            request,
            translation: "你好",
            currentResult: started.result
        )

        XCTAssertNil(result)
    }

    private var fixedRequestID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
    }

    private func snapshot(text: String) -> SelectionSnapshot {
        SelectionSnapshot(
            text: text,
            sourceBundleID: "com.example.editor",
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000),
            anchorPoint: CGPoint(x: 120, y: 240)
        )
    }
}

private extension SelectionAssistantFlowUpdate {
    var appleTranslationRequest: AppleTranslationRequest? {
        guard case .requestAppleTranslation(let request) = commands.first else { return nil }
        return request
    }

    var llmTranslationRequest: LLMTranslationRequest? {
        guard case .requestLLMTranslation(let request) = commands.first else { return nil }
        return request
    }

    var llmExplanationRequest: LLMExplanationRequest? {
        guard case .requestLLMExplanation(let request) = commands.first else { return nil }
        return request
    }
}
