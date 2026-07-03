public enum AppleLanguageDownloadStatus: Equatable, Sendable {
    case unknown
    case checking
    case downloadable
    case preparing
    case prepared
    case unsupported
}

public struct AppleLanguageDownloadControlPresentation: Equatable, Sendable {
    public var title: String
    public var systemImageName: String
    public var isDisabled: Bool
    public var helpText: String

    public static func make(
        translationEngine: TranslationEngine,
        targetLanguage: String,
        status: AppleLanguageDownloadStatus
    ) -> AppleLanguageDownloadControlPresentation? {
        guard translationEngine == .appleTranslation else {
            return nil
        }

        switch status {
        case .unknown, .checking:
            return AppleLanguageDownloadControlPresentation(
                title: "检测中",
                systemImageName: "arrow.triangle.2.circlepath",
                isDisabled: true,
                helpText: "正在检测 Apple 语言包"
            )
        case .prepared:
            return AppleLanguageDownloadControlPresentation(
                title: "已准备",
                systemImageName: "checkmark.circle.fill",
                isDisabled: true,
                helpText: "Apple 语言包已准备好"
            )
        case .preparing:
            return AppleLanguageDownloadControlPresentation(
                title: "准备中",
                systemImageName: "hourglass",
                isDisabled: true,
                helpText: "正在准备 Apple 语言包"
            )
        case .unsupported:
            return AppleLanguageDownloadControlPresentation(
                title: "不支持",
                systemImageName: "exclamationmark.triangle",
                isDisabled: true,
                helpText: "当前目标语言不支持 Apple 翻译"
            )
        case .downloadable:
            return AppleLanguageDownloadControlPresentation(
                title: "下载 Apple 语言包",
                systemImageName: "arrow.down.circle",
                isDisabled: false,
                helpText: "下载 \(targetLanguage) 的 Apple 语言包"
            )
        }
    }
}
