import XCTest
@testable import TextLensCore

final class AssistantResultFailurePresentationTests: XCTestCase {
    func testMissingAPIKeyPromptsSetupWithoutEmptyResultPlaceholder() {
        let presentation = AssistantResultFailurePresentation.make(
            for: .missingAPIKey,
            action: .translate
        )

        XCTAssertEqual(presentation.title, "需要配置 API Key")
        XCTAssertEqual(presentation.message, "设置后即可继续翻译")
        XCTAssertEqual(presentation.tone, .setup)
        XCTAssertEqual(presentation.systemImageName, "key")
        XCTAssertTrue(presentation.shouldOfferSettings)
        XCTAssertFalse(presentation.showsEmptyResultPlaceholder)
    }

    func testProviderFailureKeepsFailureCopyAndAvoidsEmptyResultPlaceholder() {
        let presentation = AssistantResultFailurePresentation.make(
            for: .providerFailure(message: "网络超时"),
            action: .explain
        )

        XCTAssertEqual(presentation.title, "解释失败")
        XCTAssertEqual(presentation.message, "网络超时")
        XCTAssertEqual(presentation.tone, .warning)
        XCTAssertEqual(presentation.systemImageName, "exclamationmark.triangle")
        XCTAssertFalse(presentation.shouldOfferSettings)
        XCTAssertFalse(presentation.showsEmptyResultPlaceholder)
    }
}
