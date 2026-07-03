import XCTest
@testable import TextLensCore

final class AppleLanguageDownloadControlPresentationTests: XCTestCase {
    func testHidesWhenTranslationEngineIsModel() {
        let presentation = AppleLanguageDownloadControlPresentation.make(
            translationEngine: .openAICompatible,
            targetLanguage: "zh-Hans",
            status: .downloadable
        )

        XCTAssertNil(presentation)
    }

    func testShowsCheckingStateUntilAppleAvailabilityIsKnown() throws {
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: "zh-Hans",
            status: .checking
        ))

        XCTAssertEqual(presentation.title, "检测中")
        XCTAssertEqual(presentation.systemImageName, "arrow.triangle.2.circlepath")
        XCTAssertTrue(presentation.isDisabled)
    }

    func testShowsDownloadForUnpreparedAppleTarget() throws {
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: "zh-Hans",
            status: .downloadable
        ))

        XCTAssertEqual(presentation.title, "下载 Apple 语言包")
        XCTAssertEqual(presentation.systemImageName, "arrow.down.circle")
        XCTAssertFalse(presentation.isDisabled)
    }

    func testShowsPreparingStateForCurrentTarget() throws {
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: "zh-Hans",
            status: .preparing
        ))

        XCTAssertEqual(presentation.title, "准备中")
        XCTAssertEqual(presentation.systemImageName, "hourglass")
        XCTAssertTrue(presentation.isDisabled)
    }

    func testShowsCheckmarkForPreparedCurrentTarget() throws {
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: "zh-Hans",
            status: .prepared
        ))

        XCTAssertEqual(presentation.title, "已准备")
        XCTAssertEqual(presentation.systemImageName, "checkmark.circle.fill")
        XCTAssertTrue(presentation.isDisabled)
    }

    func testShowsUnsupportedStateForUnsupportedTarget() throws {
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: "ru",
            status: .unsupported
        ))

        XCTAssertEqual(presentation.title, "不支持")
        XCTAssertEqual(presentation.systemImageName, "exclamationmark.triangle")
        XCTAssertTrue(presentation.isDisabled)
    }

    func testSwitchingTargetReturnsToDownloadState() throws {
        let statusesByTarget = [
            "zh-Hans": AppleLanguageDownloadStatus.prepared,
            "ja": AppleLanguageDownloadStatus.downloadable
        ]
        let selectedTarget = "ja"
        let presentation = try XCTUnwrap(AppleLanguageDownloadControlPresentation.make(
            translationEngine: .appleTranslation,
            targetLanguage: selectedTarget,
            status: statusesByTarget[selectedTarget] ?? .unknown
        ))

        XCTAssertEqual(presentation.title, "下载 Apple 语言包")
        XCTAssertEqual(presentation.systemImageName, "arrow.down.circle")
    }
}
