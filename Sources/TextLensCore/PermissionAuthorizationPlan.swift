public struct PermissionAuthorizationPlan: Equatable, Sendable {
    public var opensGuidedSettings: Bool
    public var requestsNativePrompt: Bool
    public var startsRecoveryPolling: Bool

    public static let accessibility = PermissionAuthorizationPlan(
        opensGuidedSettings: true,
        requestsNativePrompt: false,
        startsRecoveryPolling: true
    )
}
