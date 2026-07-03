import Foundation

public struct AppleLanguageDownloadPlan: Equatable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: String

    public static func make(targetLanguage: String) -> AppleLanguageDownloadPlan {
        let target = Locale.Language(identifier: targetLanguage)
        let sourceLanguage = target.languageCode?.identifier == "en" ? "zh-Hans" : "en"
        return AppleLanguageDownloadPlan(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
    }
}
