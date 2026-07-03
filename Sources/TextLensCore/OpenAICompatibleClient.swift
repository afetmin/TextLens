import Foundation

public protocol AIClient {
    func translate(text: String, targetLanguage: String) async throws -> String
    func explain(text: String, targetLanguage: String) async throws -> String
}

public enum AIClientError: Error, Equatable {
    case emptyResponse
    case invalidResponse
    case httpStatus(Int)
}

public protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPTransport: HTTPTransport {
    public init() {}

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public struct OpenAICompatibleClient: AIClient, Sendable {
    private let config: AIProviderConfig
    private let apiKey: String
    private let transport: any HTTPTransport

    public init(
        config: AIProviderConfig,
        apiKey: String,
        transport: any HTTPTransport = URLSessionHTTPTransport()
    ) {
        self.config = config
        self.apiKey = apiKey
        self.transport = transport
    }

    public func translate(text: String, targetLanguage: String) async throws -> String {
        let prompt = TranslationPrompt.make(text: text, targetLanguage: targetLanguage)
        return try await perform(
            systemPrompt: prompt.system,
            userPrompt: prompt.user
        )
    }

    public func explain(text: String, targetLanguage: String) async throws -> String {
        let prompt = ExplanationPrompt.make(text: text, targetLanguage: targetLanguage)
        return try await perform(
            systemPrompt: prompt.system,
            userPrompt: prompt.user
        )
    }

    private func perform(systemPrompt: String, userPrompt: String) async throws -> String {
        var request = URLRequest(url: config.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "model": config.model,
            "temperature": 0.2,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ])

        let (data, response) = try await transport.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw AIClientError.httpStatus(response.statusCode)
        }

        let decoded = try JSONDecoder().decode(ChatCompletionsResponse.self, from: data)
        guard let content = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else {
            throw AIClientError.emptyResponse
        }

        return content
    }
}

private struct ChatCompletionsResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    let choices: [Choice]
}

public struct TranslationPrompt: Equatable, Sendable {
    public var system: String
    public var user: String

    public static func make(text: String, targetLanguage: String) -> TranslationPrompt {
        TranslationPrompt(
            system: """
            You are a professional \(targetLanguage) native translator. Translate the user's text into \(targetLanguage).

            Translation rules:
            1. Output only the translated content, without explanations, labels, notes, quotes, or markdown fences.
            2. Keep the same number of paragraphs and format as the source text.
            3. Preserve proper nouns, code, placeholders, URLs, product names, and text that should not be translated.
            4. If the source contains markup or inline symbols, place them naturally in the translated text without dropping them.
            """,
            user: "Translate to \(targetLanguage):\n\n\(text)"
        )
    }
}

public struct ExplanationPrompt: Equatable, Sendable {
    public var system: String
    public var user: String

    public static func make(text: String, targetLanguage: String) -> ExplanationPrompt {
        ExplanationPrompt(
            system: """
            You are a concise explanation assistant for selected text. Explain the selected text in \(targetLanguage).

            Explanation rules:
            1. Do not translate as the primary task; explain meaning, usage, nuance, and likely context.
            2. If the selection is a word or phrase, cover part of speech, common meanings, tone, collocations, and when to use it.
            3. If the selection is a sentence, explain the sentence meaning, implied intent, and any idioms or difficult grammar.
            4. Keep the answer concise and structured for a small floating panel.
            5. Use \(targetLanguage) for explanations, but keep original terms, code, names, and quoted source text unchanged.
            6. Add at most one short example only when it clarifies usage.
            """,
            user: "Explain this selected text:\n\n\(text)"
        )
    }
}
