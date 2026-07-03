import XCTest
@testable import TextLensCore

final class AppleLanguageDownloadCompletionPolicyTests: XCTestCase {
    func testKeepsDownloadableWhenSystemPreparationFinishesWithoutInstallingLanguagePack() {
        let status = AppleLanguageDownloadCompletionPolicy.statusAfterPreparation(
            verifiedStatus: .downloadable
        )

        XCTAssertEqual(status, .downloadable)
    }

    func testMarksPreparedOnlyAfterVerifiedInstalledLanguagePack() {
        let status = AppleLanguageDownloadCompletionPolicy.statusAfterPreparation(
            verifiedStatus: .prepared
        )

        XCTAssertEqual(status, .prepared)
    }
}
