import XCTest
@testable import TextLensCore

final class TranslationSourceLanguageDetectorTests: XCTestCase {
    func testDetectsEnglishSourceForShortEnglishSelection() {
        let source = TranslationSourceLanguageDetector.sourceLanguageIdentifier(
            for: "hello",
            targetLanguage: "zh-Hans"
        )

        XCTAssertEqual(source, "en")
    }

    func testDetectsJapaneseSourceForJapaneseSelection() {
        let source = TranslationSourceLanguageDetector.sourceLanguageIdentifier(
            for: "こんにちは",
            targetLanguage: "zh-Hans"
        )

        XCTAssertEqual(source, "ja")
    }

    func testIgnoresSameLanguageSource() {
        let source = TranslationSourceLanguageDetector.sourceLanguageIdentifier(
            for: "hello",
            targetLanguage: "en"
        )

        XCTAssertNil(source)
    }
}
