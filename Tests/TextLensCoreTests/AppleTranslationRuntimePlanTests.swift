import XCTest
@testable import TextLensCore

final class AppleTranslationRuntimePlanTests: XCTestCase {
    func testTranslationConfigurationInvalidatesWhenIdentityMatchesCurrentConfiguration() {
        let request = AppleTranslationRequest(
            id: fixedRequestID,
            snapshot: snapshot,
            text: "hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )

        let update = AppleTranslationRuntimePlan.translationConfiguration(
            for: request,
            currentConfiguration: AppleTranslationConfigurationIdentity(
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )

        XCTAssertEqual(
            update.identity,
            AppleTranslationConfigurationIdentity(
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )
        XCTAssertTrue(update.invalidatesExistingConfiguration)
    }

    func testTranslationConfigurationDoesNotInvalidateDifferentConfiguration() {
        let request = AppleTranslationRequest(
            id: fixedRequestID,
            snapshot: snapshot,
            text: "hello",
            sourceLanguage: "en",
            targetLanguage: "zh-Hans"
        )

        let update = AppleTranslationRuntimePlan.translationConfiguration(
            for: request,
            currentConfiguration: AppleTranslationConfigurationIdentity(
                sourceLanguage: "ja",
                targetLanguage: "zh-Hans"
            )
        )

        XCTAssertFalse(update.invalidatesExistingConfiguration)
    }

    func testStartsLanguageDownloadForDownloadableAppleTarget() {
        let start = AppleTranslationRuntimePlan.startLanguageDownload(
            translationEngine: .appleTranslation,
            currentStatus: .downloadable,
            targetLanguage: "zh-Hans",
            requestID: fixedRequestID,
            currentConfiguration: nil
        )

        XCTAssertEqual(
            start,
            AppleLanguageDownloadStart(
                request: AppleLanguageDownloadRequest(
                    id: fixedRequestID,
                    sourceLanguage: "en",
                    targetLanguage: "zh-Hans"
                ),
                status: .preparing,
                configuration: AppleTranslationConfigurationUpdate(
                    identity: AppleTranslationConfigurationIdentity(
                        sourceLanguage: "en",
                        targetLanguage: "zh-Hans"
                    ),
                    invalidatesExistingConfiguration: false
                )
            )
        )
    }

    func testLanguageDownloadStartInvalidatesMatchingConfiguration() {
        let start = AppleTranslationRuntimePlan.startLanguageDownload(
            translationEngine: .appleTranslation,
            currentStatus: .downloadable,
            targetLanguage: "zh-Hans",
            requestID: fixedRequestID,
            currentConfiguration: AppleTranslationConfigurationIdentity(
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )

        XCTAssertEqual(start?.configuration.invalidatesExistingConfiguration, true)
    }

    func testDoesNotStartLanguageDownloadWhenEngineIsModel() {
        let start = AppleTranslationRuntimePlan.startLanguageDownload(
            translationEngine: .openAICompatible,
            currentStatus: .downloadable,
            targetLanguage: "zh-Hans",
            requestID: fixedRequestID,
            currentConfiguration: nil
        )

        XCTAssertNil(start)
    }

    func testDoesNotStartLanguageDownloadForTerminalOrBusyStatuses() {
        for status in [
            AppleLanguageDownloadStatus.checking,
            .preparing,
            .prepared,
            .unsupported
        ] {
            let start = AppleTranslationRuntimePlan.startLanguageDownload(
                translationEngine: .appleTranslation,
                currentStatus: status,
                targetLanguage: "zh-Hans",
                requestID: fixedRequestID,
                currentConfiguration: nil
            )

            XCTAssertNil(start, "status: \(status)")
        }
    }

    func testRefreshLanguageAvailabilityIsUnknownForModelEngine() {
        let refresh = AppleTranslationRuntimePlan.refreshLanguageAvailability(
            translationEngine: .openAICompatible,
            targetLanguage: "zh-Hans",
            activeDownloadRequest: nil
        )

        XCTAssertEqual(refresh, AppleLanguageAvailabilityRefresh(status: .unknown, query: nil))
    }

    func testRefreshLanguageAvailabilityKeepsPreparingForActiveTarget() {
        let refresh = AppleTranslationRuntimePlan.refreshLanguageAvailability(
            translationEngine: .appleTranslation,
            targetLanguage: "zh-Hans",
            activeDownloadRequest: AppleLanguageDownloadRequest(
                id: fixedRequestID,
                sourceLanguage: "en",
                targetLanguage: "zh-Hans"
            )
        )

        XCTAssertEqual(refresh, AppleLanguageAvailabilityRefresh(status: .preparing, query: nil))
    }

    func testRefreshLanguageAvailabilityBuildsQueryForInactiveTarget() {
        let refresh = AppleTranslationRuntimePlan.refreshLanguageAvailability(
            translationEngine: .appleTranslation,
            targetLanguage: "ja",
            activeDownloadRequest: nil
        )

        XCTAssertEqual(
            refresh,
            AppleLanguageAvailabilityRefresh(
                status: .checking,
                query: AppleLanguageAvailabilityQuery(sourceLanguage: "en", targetLanguage: "ja")
            )
        )
    }

    func testDownloadFailureReturnsDownloadableStatus() {
        XCTAssertEqual(
            AppleTranslationRuntimePlan.statusAfterLanguageDownloadFailure(),
            .downloadable
        )
    }

    private var fixedRequestID: UUID {
        UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
    }

    private var snapshot: SelectionSnapshot {
        SelectionSnapshot(
            text: "hello",
            sourceBundleID: nil,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_100),
            anchorPoint: .zero
        )
    }
}
