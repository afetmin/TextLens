import Foundation

public protocol SecretStoring {
    func saveAPIKey(_ apiKey: String) throws
    func loadAPIKey() throws -> String?
    func deleteAPIKey() throws
}

public final class InMemorySecretStore: SecretStoring {
    private var apiKey: String?

    public init() {}

    public func saveAPIKey(_ apiKey: String) throws {
        self.apiKey = apiKey
    }

    public func loadAPIKey() throws -> String? {
        apiKey
    }

    public func deleteAPIKey() throws {
        apiKey = nil
    }
}

public final class UserDefaultsSecretStore: SecretStoring {
    private let userDefaults: UserDefaults
    private let apiKeyKey: String

    public init(
        userDefaults: UserDefaults = .standard,
        apiKeyKey: String = "TextLens.openAICompatibleAPIKey"
    ) {
        self.userDefaults = userDefaults
        self.apiKeyKey = apiKeyKey
    }

    public func saveAPIKey(_ apiKey: String) throws {
        userDefaults.set(apiKey, forKey: apiKeyKey)
    }

    public func loadAPIKey() throws -> String? {
        userDefaults.string(forKey: apiKeyKey)
    }

    public func deleteAPIKey() throws {
        userDefaults.removeObject(forKey: apiKeyKey)
    }
}
