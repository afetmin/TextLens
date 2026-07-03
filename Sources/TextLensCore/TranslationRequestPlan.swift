import Foundation
import NaturalLanguage

public enum TranslationRequestPlan: Equatable, Sendable {
    case useOriginalText
    case translate(sourceLanguage: String?)

    public static func make(text: String, targetLanguage: String) -> TranslationRequestPlan {
        guard let language = NLLanguageRecognizer.dominantLanguage(for: text) else {
            return .translate(sourceLanguage: nil)
        }

        let sourceIdentifier = language.rawValue
        let source = Locale.Language(identifier: sourceIdentifier)
        let target = Locale.Language(identifier: targetLanguage)
        guard source.languageCode != target.languageCode else {
            return .useOriginalText
        }

        return .translate(sourceLanguage: sourceIdentifier)
    }
}
