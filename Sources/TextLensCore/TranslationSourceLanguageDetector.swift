public enum TranslationSourceLanguageDetector {
    public static func sourceLanguageIdentifier(
        for text: String,
        targetLanguage: String
    ) -> String? {
        switch TranslationRequestPlan.make(text: text, targetLanguage: targetLanguage) {
        case .useOriginalText:
            return nil
        case let .translate(sourceLanguage):
            return sourceLanguage
        }
    }
}
