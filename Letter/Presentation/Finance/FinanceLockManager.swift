import Foundation
import Observation

extension FinanceBiometry {
    var title: String {
        switch self {
        case .unavailable, .other: "finance.lock.method.biometrics".localized
        case .touchID: "Touch ID"
        case .faceID: "Face ID"
        }
    }

    var systemImage: String {
        switch self {
        case .touchID: "touchid"
        case .faceID: "faceid"
        case .unavailable, .other: "person.badge.key"
        }
    }
}

@MainActor
@Observable
final class FinanceLockManager {
    private(set) var method: FinanceLockMethod
    private(set) var isUnlocked: Bool
    private(set) var isAuthenticating = false
    private(set) var biometry: FinanceBiometry = .unavailable
    private(set) var canUseBiometrics = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let useCase: any FinanceLockUseCase
    @ObservationIgnored private var authenticationAttemptID: UUID?

    init(useCase: any FinanceLockUseCase) {
        self.useCase = useCase
        let method = useCase.loadMethod()
        self.method = method
        isUnlocked = method == .none
        refreshBiometryAvailability()
    }

    var requiresAuthentication: Bool {
        method != .none && !isUnlocked
    }

    func refreshBiometryAvailability() {
        let status = useCase.biometryStatus()
        biometry = status.biometry
        canUseBiometrics = status.isAvailable
    }

    func lock() {
        authenticationAttemptID = nil
        useCase.cancelAuthentication()
        isAuthenticating = false
        isUnlocked = method == .none
        errorMessage = nil
    }

    @discardableResult
    func unlock(withPIN pin: String) -> Bool {
        do {
            try useCase.verifyPIN(pin)
            errorMessage = nil
            isUnlocked = true
            Haptic.success()
            return true
        } catch {
            present(error)
            if error as? FinanceLockError == .incorrectPIN { Haptic.warning() }
            return false
        }
    }

    @discardableResult
    func configurePIN(_ pin: String) -> Bool {
        do {
            try useCase.configurePIN(pin)
            method = .pin
            isUnlocked = true
            errorMessage = nil
            Haptic.success()
            return true
        } catch {
            present(error)
            return false
        }
    }

    @discardableResult
    func enableBiometricProtection() async -> Bool {
        refreshBiometryAvailability()
        return await authenticate {
            try await useCase.enableBiometricProtection(
                reason: "finance.lock.biometric.enableReason".localized
            )
            method = .biometrics
            isUnlocked = true
        }
    }

    @discardableResult
    func unlockWithDeviceAuthentication() async -> Bool {
        guard method == .biometrics else { return false }
        return await authenticate {
            try await useCase.authenticateDevice(
                reason: "finance.lock.biometric.unlockReason".localized
            )
            isUnlocked = true
        }
    }

    @discardableResult
    func authorizeCurrentMethod() async -> Bool {
        await authenticate(showsSuccessFeedback: false) {
            let authorized = try await useCase.authorizeCurrentMethod(
                method,
                isUnlocked: isUnlocked,
                reason: "finance.lock.settings.authorizeReason".localized
            )
            guard authorized else { throw FinanceLockError.unavailable }
        }
    }

    @discardableResult
    func disableProtection() -> Bool {
        do {
            try useCase.disableProtection()
            method = .none
            isUnlocked = true
            errorMessage = nil
            Haptic.success()
            return true
        } catch {
            present(error)
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    static func isValidPIN(_ pin: String) -> Bool {
        FinancePIN.isValid(pin)
    }
}

private extension FinanceLockManager {
    func authenticate(
        showsSuccessFeedback: Bool = true,
        operation: () async throws -> Void
    ) async -> Bool {
        guard !isAuthenticating else { return false }
        let attemptID = UUID()
        authenticationAttemptID = attemptID
        isAuthenticating = true
        errorMessage = nil

        do {
            try await operation()
            guard authenticationAttemptID == attemptID else { return false }
            finishAuthentication(attemptID)
            if showsSuccessFeedback { Haptic.success() }
            return true
        } catch {
            guard authenticationAttemptID == attemptID else { return false }
            finishAuthentication(attemptID)
            present(error)
            return false
        }
    }

    func finishAuthentication(_ attemptID: UUID) {
        guard authenticationAttemptID == attemptID else { return }
        authenticationAttemptID = nil
        isAuthenticating = false
    }

    func present(_ error: Error) {
        guard let error = error as? FinanceLockError else {
            errorMessage = "finance.lock.error.unavailable".localized
            return
        }

        errorMessage = switch error {
        case .invalidPIN: "finance.lock.pin.invalid".localized
        case .incorrectPIN: "finance.lock.pin.incorrect".localized
        case .biometricsUnavailable: "finance.lock.biometric.unavailable".localized
        case .biometricsNotEnrolled: "finance.lock.biometric.notEnrolled".localized
        case .biometricsLocked: "finance.lock.biometric.lockout".localized
        case .passcodeNotSet: "finance.lock.passcode.notSet".localized
        case .authenticationFailed: "finance.lock.error.failed".localized
        case .authenticationCancelled: nil
        case .saveFailed: "finance.lock.error.save".localized
        case .unavailable: "finance.lock.error.unavailable".localized
        }
    }
}
