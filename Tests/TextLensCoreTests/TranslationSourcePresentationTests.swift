import XCTest
@testable import TextLensCore

final class TranslationSourcePresentationTests: XCTestCase {
    func testAppleTranslationSourceUsesCompactAppleLabel() {
        let presentation = TranslationSourcePresentation.make(for: .appleTranslation)

        XCTAssertEqual(presentation.label, "Apple")
        XCTAssertEqual(presentation.accessibilityLabel, "Apple 翻译")
        XCTAssertEqual(presentation.helpText, "使用 Apple 翻译")
    }

    func testOpenAICompatibleSourceUsesCompactModelLabel() {
        let presentation = TranslationSourcePresentation.make(for: .openAICompatible)

        XCTAssertEqual(presentation.label, "大模型")
        XCTAssertEqual(presentation.accessibilityLabel, "大模型翻译")
        XCTAssertEqual(presentation.helpText, "使用大模型翻译")
    }

    func testAppleFallbackSourceStillShowsModelAsFinalSource() {
        let presentation = TranslationSourcePresentation.make(for: .openAICompatibleAfterAppleFallback)

        XCTAssertEqual(presentation.label, "大模型")
        XCTAssertEqual(presentation.accessibilityLabel, "Apple 翻译失败，已回退到大模型翻译")
        XCTAssertEqual(presentation.helpText, "Apple 翻译失败，已回退到大模型")
    }

    func testOriginalTextSourceShowsCompactOriginalLabel() {
        let presentation = TranslationSourcePresentation.make(for: .originalText)

        XCTAssertEqual(presentation.label, "原文")
        XCTAssertEqual(presentation.accessibilityLabel, "源语言已是目标语言")
        XCTAssertEqual(presentation.helpText, "源语言已是目标语言，直接显示原文")
    }
}
