import XCTest
@testable import TextLensCore

final class TranslationRequestPlanTests: XCTestCase {
    func testUsesOriginalTextWhenDetectedLanguageMatchesTarget() {
        let plan = TranslationRequestPlan.make(
            text: "hello",
            targetLanguage: "en"
        )

        XCTAssertEqual(plan, .useOriginalText)
    }

    func testRequestsTranslationWhenDetectedLanguageDiffersFromTarget() {
        let plan = TranslationRequestPlan.make(
            text: "hello",
            targetLanguage: "zh-Hans"
        )

        XCTAssertEqual(plan, .translate(sourceLanguage: "en"))
    }
}
