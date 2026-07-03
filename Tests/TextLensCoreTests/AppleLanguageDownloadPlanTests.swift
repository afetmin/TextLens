import XCTest
@testable import TextLensCore

final class AppleLanguageDownloadPlanTests: XCTestCase {
    func testUsesEnglishAsReferenceSourceForNonEnglishTarget() {
        let plan = AppleLanguageDownloadPlan.make(targetLanguage: "zh-Hans")

        XCTAssertEqual(plan.sourceLanguage, "en")
        XCTAssertEqual(plan.targetLanguage, "zh-Hans")
    }

    func testUsesChineseAsReferenceSourceForEnglishTarget() {
        let plan = AppleLanguageDownloadPlan.make(targetLanguage: "en")

        XCTAssertEqual(plan.sourceLanguage, "zh-Hans")
        XCTAssertEqual(plan.targetLanguage, "en")
    }
}
