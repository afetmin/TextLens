import Foundation

public enum MenuBarStatusPolicy {
    private static let hiddenMessages: Set<String> = [
        "已准备读取选区",
        "已获得辅助功能权限",
        "已获得辅助功能权限，划词监听已开启",
        "划词自动弹出已开启",
        "划词自动弹出已关闭",
        "已复制",
        "没有前台应用",
        "需要辅助功能权限",
        "请在系统设置中授权",
        "仍未检测到辅助功能权限",
        "当前应用没有可读取的焦点控件",
        "当前应用未暴露选中文本"
    ]

    public static func displayMessage(for statusMessage: String) -> String? {
        let message = statusMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty, !hiddenMessages.contains(message) else { return nil }
        return message
    }
}
