public struct TargetLanguageOption: Equatable, Hashable, Sendable {
    public var code: String
    public var name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }

    public static let common: [TargetLanguageOption] = [
        TargetLanguageOption(code: "zh-Hans", name: "简体中文"),
        TargetLanguageOption(code: "zh-Hant", name: "繁體中文"),
        TargetLanguageOption(code: "en", name: "English"),
        TargetLanguageOption(code: "ja", name: "日本語"),
        TargetLanguageOption(code: "ko", name: "한국어"),
        TargetLanguageOption(code: "fr", name: "Français"),
        TargetLanguageOption(code: "de", name: "Deutsch"),
        TargetLanguageOption(code: "es", name: "Español"),
        TargetLanguageOption(code: "ru", name: "Русский")
    ]
}
