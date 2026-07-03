public struct PermissionRecoveryCoordinator: Sendable {
    private var isWaitingForPermission = false

    public init() {}

    public mutating func recordPermissionPrompt() {
        isWaitingForPermission = true
    }

    public mutating func observeTrustedState(_ isTrusted: Bool) -> Bool {
        guard isWaitingForPermission, isTrusted else {
            return false
        }
        isWaitingForPermission = false
        return true
    }
}
