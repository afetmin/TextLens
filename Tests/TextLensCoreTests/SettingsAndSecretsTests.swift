import Foundation
import XCTest
@testable import TextLensCore

final class SettingsAndSecretsTests: XCTestCase {
    func testDefaultSettingsUseAppleTranslationAndLLMExplanation() {
        let settings = AppSettings.default

        XCTAssertTrue(settings.selectionPopupEnabled)
        XCTAssertEqual(settings.targetLanguage, "zh-Hans")
        XCTAssertEqual(settings.translationEngine, .appleTranslation)
        XCTAssertEqual(settings.explanationEngine, .openAICompatible)
    }

    func testTranslationOffersAppleFirstAndLLMFallbackEngines() {
        XCTAssertEqual(TranslationEngine.allCases, [.appleTranslation, .openAICompatible])
        XCTAssertEqual(ExplanationEngine.allCases, [.openAICompatible])
    }

    func testCommonTargetLanguageOptionsIncludeFrequentChoices() {
        let options = TargetLanguageOption.common

        XCTAssertEqual(options.first, TargetLanguageOption(code: "zh-Hans", name: "简体中文"))
        XCTAssertTrue(options.contains(TargetLanguageOption(code: "en", name: "English")))
        XCTAssertTrue(options.contains(TargetLanguageOption(code: "ja", name: "日本語")))
        XCTAssertTrue(options.contains(TargetLanguageOption(code: "ko", name: "한국어")))
    }

    func testDecodesLegacyAppleTranslationEngine() throws {
        let data = Data("""
        {
          "selectionPopupEnabled": true,
          "targetLanguage": "ja",
          "translationEngine": "appleTranslation",
          "explanationEngine": "foundationModels",
          "providerConfig": {
            "baseURL": "https://api.example.com/v1",
            "model": "custom-model"
          }
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.targetLanguage, "ja")
        XCTAssertEqual(settings.translationEngine, .appleTranslation)
        XCTAssertEqual(settings.explanationEngine, .openAICompatible)
        XCTAssertEqual(settings.providerConfig.model, "custom-model")
    }

    func testMigratesLegacyOpenAITranslationEngineToAppleTranslation() throws {
        let data = Data("""
        {
          "selectionPopupEnabled": true,
          "targetLanguage": "ko",
          "translationEngine": "openAICompatible",
          "explanationEngine": "openAICompatible"
        }
        """.utf8)

        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.targetLanguage, "ko")
        XCTAssertEqual(settings.translationEngine, .appleTranslation)
    }

    func testRoundTripsCurrentOpenAITranslationEngineChoice() throws {
        let settings = AppSettings(
            selectionPopupEnabled: true,
            targetLanguage: "en",
            translationEngine: .openAICompatible,
            explanationEngine: .openAICompatible,
            providerConfig: .default
        )

        let data = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(decoded.translationEngine, .openAICompatible)
    }

    func testChatCompletionsURLNormalizesBasePath() {
        let rootConfig = AIProviderConfig(baseURL: URL(string: "https://api.example.com")!, model: "m")
        let versionedConfig = AIProviderConfig(baseURL: URL(string: "https://api.example.com/v1/")!, model: "m")

        XCTAssertEqual(rootConfig.chatCompletionsURL.absoluteString, "https://api.example.com/v1/chat/completions")
        XCTAssertEqual(versionedConfig.chatCompletionsURL.absoluteString, "https://api.example.com/v1/chat/completions")
    }

    func testMemorySecretStoreSavesLoadsAndDeletesAPIKey() throws {
        let store = InMemorySecretStore()

        XCTAssertNil(try store.loadAPIKey())

        try store.saveAPIKey("sk-test")
        XCTAssertEqual(try store.loadAPIKey(), "sk-test")

        try store.deleteAPIKey()
        XCTAssertNil(try store.loadAPIKey())
    }

    func testUserDefaultsSecretStoreSavesLoadsAndDeletesAPIKey() throws {
        let suiteName = "TextLensTests.\(UUID().uuidString)"
        let userDefaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            userDefaults.removePersistentDomain(forName: suiteName)
        }
        let store = UserDefaultsSecretStore(userDefaults: userDefaults)

        XCTAssertNil(try store.loadAPIKey())

        try store.saveAPIKey("sk-local-test")
        XCTAssertEqual(try store.loadAPIKey(), "sk-local-test")

        try store.deleteAPIKey()
        XCTAssertNil(try store.loadAPIKey())
    }
}
