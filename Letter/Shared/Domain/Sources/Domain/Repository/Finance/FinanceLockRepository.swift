@MainActor
public protocol FinanceLockRepository: AnyObject {
    func loadMethod() -> FinanceLockMethod?
    func loadPIN() -> String?
    func savePINProtection(_ pin: String) throws
    func saveBiometricProtection() throws
    func clearProtection() throws

    func biometryStatus() -> FinanceBiometryStatus
    func authenticate(
        policy: FinanceAuthenticationPolicy,
        reason: String
    ) async throws
    func cancelAuthentication()
}
