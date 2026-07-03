public struct PermissionStatusPresentation: Equatable, Sendable {
    public var title: String
    public var status: String
    public var systemImage: String
    public var actionTitle: String
    public var isActionDisabled: Bool

    public static func accessibility(isTrusted: Bool) -> PermissionStatusPresentation {
        PermissionStatusPresentation(
            title: "辅助功能",
            status: isTrusted ? "已授权" : "未授权",
            systemImage: isTrusted ? "checkmark.seal.fill" : "arrow.right.circle.fill",
            actionTitle: isTrusted ? "已完成" : "授权",
            isActionDisabled: isTrusted
        )
    }
}
