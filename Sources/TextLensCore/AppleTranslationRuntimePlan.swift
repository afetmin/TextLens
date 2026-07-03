import Foundation

public struct AppleLanguageDownloadRequest: Equatable, Sendable {
    public var id: UUID
    public var sourceLanguage: String
    public var targetLanguage: String

    public init(id: UUID, sourceLanguage: String, targetLanguage: String) {
        self.id = id
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public struct AppleTranslationConfigurationIdentity: Equatable, Sendable {
    public var sourceLanguage: String?
    public var targetLanguage: String

    public init(sourceLanguage: String?, targetLanguage: String) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public struct AppleTranslationConfigurationUpdate: Equatable, Sendable {
    public var identity: AppleTranslationConfigurationIdentity
    public var invalidatesExistingConfiguration: Bool

    public init(
        identity: AppleTranslationConfigurationIdentity,
        invalidatesExistingConfiguration: Bool
    ) {
        self.identity = identity
        self.invalidatesExistingConfiguration = invalidatesExistingConfiguration
    }
}

public struct AppleLanguageDownloadStart: Equatable, Sendable {
    public var request: AppleLanguageDownloadRequest
    public var status: AppleLanguageDownloadStatus
    public var configuration: AppleTranslationConfigurationUpdate

    public init(
        request: AppleLanguageDownloadRequest,
        status: AppleLanguageDownloadStatus,
        configuration: AppleTranslationConfigurationUpdate
    ) {
        self.request = request
        self.status = status
        self.configuration = configuration
    }
}

public struct AppleLanguageAvailabilityQuery: Equatable, Sendable {
    public var sourceLanguage: String
    public var targetLanguage: String

    public init(sourceLanguage: String, targetLanguage: String) {
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
    }
}

public struct AppleLanguageAvailabilityRefresh: Equatable, Sendable {
    public var status: AppleLanguageDownloadStatus
    public var query: AppleLanguageAvailabilityQuery?

    public init(status: AppleLanguageDownloadStatus, query: AppleLanguageAvailabilityQuery?) {
        self.status = status
        self.query = query
    }
}

public enum AppleTranslationRuntimePlan {
    public static func translationConfiguration(
        for request: AppleTranslationRequest,
        currentConfiguration: AppleTranslationConfigurationIdentity?
    ) -> AppleTranslationConfigurationUpdate {
        configurationUpdate(
            sourceLanguage: request.sourceLanguage,
            targetLanguage: request.targetLanguage,
            currentConfiguration: currentConfiguration
        )
    }

    public static func startLanguageDownload(
        translationEngine: TranslationEngine,
        currentStatus: AppleLanguageDownloadStatus,
        targetLanguage: String,
        requestID: UUID,
        currentConfiguration: AppleTranslationConfigurationIdentity?
    ) -> AppleLanguageDownloadStart? {
        guard translationEngine == .appleTranslation else { return nil }
        guard currentStatus != .checking,
              currentStatus != .preparing,
              currentStatus != .prepared,
              currentStatus != .unsupported
        else {
            return nil
        }

        let plan = AppleLanguageDownloadPlan.make(targetLanguage: targetLanguage)
        let request = AppleLanguageDownloadRequest(
            id: requestID,
            sourceLanguage: plan.sourceLanguage,
            targetLanguage: plan.targetLanguage
        )
        return AppleLanguageDownloadStart(
            request: request,
            status: .preparing,
            configuration: configurationUpdate(
                sourceLanguage: request.sourceLanguage,
                targetLanguage: request.targetLanguage,
                currentConfiguration: currentConfiguration
            )
        )
    }

    public static func refreshLanguageAvailability(
        translationEngine: TranslationEngine,
        targetLanguage: String,
        activeDownloadRequest: AppleLanguageDownloadRequest?
    ) -> AppleLanguageAvailabilityRefresh {
        guard translationEngine == .appleTranslation else {
            return AppleLanguageAvailabilityRefresh(status: .unknown, query: nil)
        }

        if activeDownloadRequest?.targetLanguage == targetLanguage {
            return AppleLanguageAvailabilityRefresh(status: .preparing, query: nil)
        }

        let plan = AppleLanguageDownloadPlan.make(targetLanguage: targetLanguage)
        return AppleLanguageAvailabilityRefresh(
            status: .checking,
            query: AppleLanguageAvailabilityQuery(
                sourceLanguage: plan.sourceLanguage,
                targetLanguage: plan.targetLanguage
            )
        )
    }

    public static func statusAfterLanguageDownloadFailure() -> AppleLanguageDownloadStatus {
        .downloadable
    }

    private static func configurationUpdate(
        sourceLanguage: String?,
        targetLanguage: String,
        currentConfiguration: AppleTranslationConfigurationIdentity?
    ) -> AppleTranslationConfigurationUpdate {
        let identity = AppleTranslationConfigurationIdentity(
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage
        )
        return AppleTranslationConfigurationUpdate(
            identity: identity,
            invalidatesExistingConfiguration: currentConfiguration == identity
        )
    }
}
