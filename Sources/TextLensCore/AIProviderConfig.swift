import Foundation

public struct AIProviderConfig: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var model: String

    public init(baseURL: URL, model: String) {
        self.baseURL = baseURL
        self.model = model
    }

    public static let `default` = AIProviderConfig(
        baseURL: URL(string: "https://api.openai.com")!,
        model: "gpt-4.1-mini"
    )

    public var chatCompletionsURL: URL {
        var url = baseURL.standardizedFileURL
        let components = url.pathComponents.filter { $0 != "/" }
        if components.last != "v1" {
            url.appendPathComponent("v1")
        }
        url.appendPathComponent("chat")
        url.appendPathComponent("completions")
        return url
    }
}
