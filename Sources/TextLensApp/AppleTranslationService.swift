import Foundation
import TextLensCore
@preconcurrency import Translation

struct AppleTranslationService {
    func downloadStatus(sourceLanguage: String, targetLanguage: String) async -> AppleLanguageDownloadStatus {
        let source = Locale.Language(identifier: sourceLanguage)
        let target = Locale.Language(identifier: targetLanguage)
        let availability = makeLanguageAvailability()
        let status = await availability.status(from: source, to: target)

        switch status {
        case .installed:
            return .prepared
        case .supported:
            return .downloadable
        case .unsupported:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }

    func prepare(_ request: AppleLanguageDownloadRequest, using session: TranslationSession) async throws {
        let source = Locale.Language(identifier: request.sourceLanguage)
        let target = Locale.Language(identifier: request.targetLanguage)
        let availability = makeLanguageAvailability()
        let status = await availability.status(from: source, to: target)
        guard status != .unsupported else {
            throw AppleTranslationFailure.unsupportedLanguagePairing
        }

        try await session.prepareTranslation()
    }

    func translate(_ request: AppleTranslationRequest, using session: TranslationSession) async throws -> String {
        let source = request.sourceLanguage.map(Locale.Language.init(identifier:))
        let target = Locale.Language(identifier: request.targetLanguage)
        let availability = makeLanguageAvailability()
        let status: LanguageAvailability.Status
        if let source {
            status = await availability.status(from: source, to: target)
        } else {
            status = try await availability.status(for: request.text, to: target)
        }
        guard status != .unsupported else {
            throw AppleTranslationFailure.unsupportedLanguagePairing
        }

        try await session.prepareTranslation()
        let response = try await session.translate(request.text)
        return response.targetText
    }

    private func makeLanguageAvailability() -> LanguageAvailability {
        if #available(macOS 26.4, *) {
            return LanguageAvailability(preferredStrategy: .lowLatency)
        }
        return LanguageAvailability()
    }
}

private enum AppleTranslationFailure: LocalizedError {
    case unsupportedLanguagePairing

    var errorDescription: String? {
        switch self {
        case .unsupportedLanguagePairing:
            "当前语言暂不支持系统翻译"
        }
    }
}
