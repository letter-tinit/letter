@MainActor
public protocol FinanceLockUseCase {
    func loadMethod() -> FinanceLockMethod
    func biometryStatus() -> FinanceBiometryStatus
    func verifyPIN(_ pin: String) throws
    func configurePIN(_ pin: String) throws
    func enableBiometricProtection(reason: String) async throws
    func authenticateDevice(reason: String) async throws
    func authorizeCurrentMethod(
        _ method: FinanceLockMethod,
        isUnlocked: Bool,
        reason: String
    ) async throws -> Bool
    func disableProtection() throws
    func cancelAuthentication()
}

@MainActor
public final class ImpFinanceLockUseCase: FinanceLockUseCase {
    private let repository: any FinanceLockRepository

    public init(repository: any FinanceLockRepository) {
        self.repository = repository
    }

    public func loadMethod() -> FinanceLockMethod {
        let method = repository.loadMethod() ?? .none
        guard method != .pin || repository.loadPIN() != nil else {
            try? repository.clearProtection()
            return .none
        }
        return method
    }

    public func biometryStatus() -> FinanceBiometryStatus {
        repository.biometryStatus()
    }

    public func verifyPIN(_ pin: String) throws {
        guard loadMethod() == .pin, let storedPIN = repository.loadPIN() else {
            throw FinanceLockError.unavailable
        }
        guard FinancePIN.securelyMatches(pin, storedPIN) else {
            throw FinanceLockError.incorrectPIN
        }
    }

    public func configurePIN(_ pin: String) throws {
        guard FinancePIN.isValid(pin) else { throw FinanceLockError.invalidPIN }
        do {
            try repository.savePINProtection(pin)
        } catch {
            throw FinanceLockError.saveFailed
        }
    }

    public func enableBiometricProtection(reason: String) async throws {
        guard repository.biometryStatus().isAvailable else {
            throw FinanceLockError.biometricsUnavailable
        }
        try await repository.authenticate(policy: .biometrics, reason: reason)
        do {
            try repository.saveBiometricProtection()
        } catch {
            throw FinanceLockError.saveFailed
        }
    }

    public func authenticateDevice(reason: String) async throws {
        try await repository.authenticate(policy: .deviceOwner, reason: reason)
    }

    public func authorizeCurrentMethod(
        _ method: FinanceLockMethod,
        isUnlocked: Bool,
        reason: String
    ) async throws -> Bool {
        switch method {
        case .none:
            return true
        case .pin:
            return isUnlocked
        case .biometrics:
            try await authenticateDevice(reason: reason)
            return true
        }
    }

    public func disableProtection() throws {
        do {
            try repository.clearProtection()
        } catch {
            throw FinanceLockError.saveFailed
        }
    }

    public func cancelAuthentication() {
        repository.cancelAuthentication()
    }
}
