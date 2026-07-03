import Foundation
import XCTest
@testable import TextLensCore

final class OpenAICompatibleClientTests: XCTestCase {
    func testTranslateBuildsChatCompletionsRequestAndParsesResponse() async throws {
        let response = """
        {"choices":[{"message":{"content":"意外发现"}}]}
        """
        let transport = RecordingHTTPTransport(responseBody: Data(response.utf8))
        let client = OpenAICompatibleClient(
            config: AIProviderConfig(
                baseURL: URL(string: "https://api.example.com")!,
                model: "example-model"
            ),
            apiKey: "test-key",
            transport: transport
        )

        let translation = try await client.translate(text: "serendipity", targetLanguage: "zh-Hans")

        XCTAssertEqual(translation, "意外发现")
        XCTAssertEqual(transport.recordedRequest?.url?.absoluteString, "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(transport.recordedRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.recordedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")

        let body = try XCTUnwrap(transport.recordedJSONBody)
        XCTAssertEqual(body["model"] as? String, "example-model")

        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        XCTAssertEqual(messages.first?["role"], "system")
        XCTAssertTrue(messages.first?["content"]?.contains("zh-Hans") == true)
        XCTAssertEqual(messages.last?["role"], "user")
        XCTAssertTrue(messages.last?["content"]?.contains("serendipity") == true)
    }

    func testTranslateUsesTranslationOnlyPromptRules() async throws {
        let response = """
        {"choices":[{"message":{"content":"你好，世界。"}}]}
        """
        let transport = RecordingHTTPTransport(responseBody: Data(response.utf8))
        let client = OpenAICompatibleClient(
            config: AIProviderConfig(
                baseURL: URL(string: "https://api.example.com")!,
                model: "example-model"
            ),
            apiKey: "test-key",
            transport: transport
        )

        let translation = try await client.translate(text: "Hello, world.", targetLanguage: "zh-Hans")

        XCTAssertEqual(translation, "你好，世界。")

        let body = try XCTUnwrap(transport.recordedJSONBody)
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        let systemPrompt = try XCTUnwrap(messages.first?["content"])
        let userPrompt = try XCTUnwrap(messages.last?["content"])

        XCTAssertTrue(systemPrompt.contains("professional zh-Hans native translator"))
        XCTAssertTrue(systemPrompt.contains("Output only the translated content"))
        XCTAssertTrue(systemPrompt.contains("without explanations"))
        XCTAssertTrue(systemPrompt.contains("same number of paragraphs and format"))
        XCTAssertTrue(systemPrompt.contains("proper nouns, code"))
        XCTAssertEqual(userPrompt, "Translate to zh-Hans:\n\nHello, world.")
    }

    func testExplainBuildsChatCompletionsRequestAndParsesResponse() async throws {
        let response = """
        {"choices":[{"message":{"content":"serendipity 指意外发现美好事物的能力或经历。"}}]}
        """
        let transport = RecordingHTTPTransport(responseBody: Data(response.utf8))
        let client = OpenAICompatibleClient(
            config: AIProviderConfig(
                baseURL: URL(string: "https://api.example.com")!,
                model: "example-model"
            ),
            apiKey: "test-key",
            transport: transport
        )

        let explanation = try await client.explain(text: "serendipity", targetLanguage: "zh-Hans")

        XCTAssertEqual(explanation, "serendipity 指意外发现美好事物的能力或经历。")
        XCTAssertEqual(transport.recordedRequest?.url?.absoluteString, "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(transport.recordedRequest?.httpMethod, "POST")
        XCTAssertEqual(transport.recordedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-key")
    }

    func testExplainUsesExplanationOnlyPromptRules() async throws {
        let response = """
        {"choices":[{"message":{"content":"这是一个问候语，语气轻松。"}}]}
        """
        let transport = RecordingHTTPTransport(responseBody: Data(response.utf8))
        let client = OpenAICompatibleClient(
            config: AIProviderConfig(
                baseURL: URL(string: "https://api.example.com")!,
                model: "example-model"
            ),
            apiKey: "test-key",
            transport: transport
        )

        _ = try await client.explain(text: "What's up?", targetLanguage: "zh-Hans")

        let body = try XCTUnwrap(transport.recordedJSONBody)
        let messages = try XCTUnwrap(body["messages"] as? [[String: String]])
        let systemPrompt = try XCTUnwrap(messages.first?["content"])
        let userPrompt = try XCTUnwrap(messages.last?["content"])

        XCTAssertTrue(systemPrompt.contains("explanation assistant"))
        XCTAssertTrue(systemPrompt.contains("Explain the selected text in zh-Hans"))
        XCTAssertTrue(systemPrompt.contains("Do not translate as the primary task"))
        XCTAssertTrue(systemPrompt.contains("meaning, usage, nuance"))
        XCTAssertTrue(systemPrompt.contains("concise"))
        XCTAssertEqual(userPrompt, "Explain this selected text:\n\nWhat's up?")
    }

    func testThrowsWhenResponseDoesNotContainContent() async {
        let transport = RecordingHTTPTransport(responseBody: Data(#"{"choices":[]}"#.utf8))
        let client = OpenAICompatibleClient(
            config: AIProviderConfig(baseURL: URL(string: "https://api.example.com/v1")!, model: "example-model"),
            apiKey: "test-key",
            transport: transport
        )

        await XCTAssertThrowsErrorAsync(try await client.translate(text: "hello", targetLanguage: "zh-Hans")) { error in
            XCTAssertEqual(error as? AIClientError, .emptyResponse)
        }
    }
}

private final class RecordingHTTPTransport: HTTPTransport, @unchecked Sendable {
    private(set) var recordedRequest: URLRequest?
    private let responseBody: Data

    var recordedJSONBody: [String: Any]? {
        guard let data = recordedRequest?.httpBody else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    init(responseBody: Data) {
        self.responseBody = responseBody
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedRequest = request
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        return (responseBody, response)
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: @autoclosure () async throws -> some Any,
    verify: (Error) -> Void,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        verify(error)
    }
}
