import Foundation
import LocalAuthentication
import Observation
import Security

enum FinanceLockMethod: String, Codable, Sendable {
    case none
    case pin
    case biometrics
}

enum FinanceBiometry: Sendable {
    case unavailable
    case touchID
    case faceID
    case other

    var title: String {
        switch self {
        case .unavailable, .other:
            "finance.lock.method.biometrics".localized
        case .touchID:
            "Touch ID"
        case .faceID:
            "Face ID"
        }
    }

    var systemImage: String {
        switch self {
        case .touchID:
            "touchid"
        case .faceID:
            "faceid"
        case .unavailable, .other:
            "person.badge.key"
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

    @ObservationIgnored private let credentialStore: FinanceLockCredentialStore
    @ObservationIgnored private var authenticationContext: LAContext?
    @ObservationIgnored private var authenticationAttemptID: UUID?

    init(credentialStore: FinanceLockCredentialStore? = nil) {
        let credentialStore = credentialStore ?? KeychainFinanceLockCredentialStore()
        self.credentialStore = credentialStore

        let storedMethod = credentialStore.loadMethod() ?? .none
        let resolvedMethod: FinanceLockMethod
        if storedMethod == .pin, credentialStore.loadPIN() == nil {
            // Fail safely after an inconsistent Keychain write without permanently
            // locking the user out of their finance data.
            credentialStore.clear()
            resolvedMethod = .none
        } else {
            resolvedMethod = storedMethod
        }

        method = resolvedMethod
        isUnlocked = resolvedMethod == .none
        refreshBiometryAvailability()
    }

    var requiresAuthentication: Bool {
        method != .none && !isUnlocked
    }

    func refreshBiometryAvailability() {
        let context = LAContext()
        var error: NSError?
        canUseBiometrics = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        switch context.biometryType {
        case .touchID:
            biometry = .touchID
        case .faceID:
            biometry = .faceID
        case .opticID:
            biometry = .other
        case .none:
            biometry = .unavailable
        @unknown default:
            biometry = .other
        }
    }

    func lock() {
        authenticationAttemptID = nil
        authenticationContext?.invalidate()
        authenticationContext = nil
        isAuthenticating = false
        isUnlocked = method == .none
        errorMessage = nil
    }

    @discardableResult
    func unlock(withPIN pin: String) -> Bool {
        guard method == .pin, let storedPIN = credentialStore.loadPIN() else {
            errorMessage = "finance.lock.error.unavailable".localized
            return false
        }

        guard Self.securelyMatches(pin, storedPIN) else {
            errorMessage = "finance.lock.pin.incorrect".localized
            Haptic.warning()
            return false
        }

        errorMessage = nil
        isUnlocked = true
        Haptic.success()
        return true
    }

    @discardableResult
    func configurePIN(_ pin: String) -> Bool {
        guard Self.isValidPIN(pin) else {
            errorMessage = "finance.lock.pin.invalid".localized
            return false
        }

        do {
            try credentialStore.savePINProtection(pin)
            method = .pin
            isUnlocked = true
            errorMessage = nil
            Haptic.success()
            return true
        } catch {
            errorMessage = "finance.lock.error.save".localized
            return false
        }
    }

    @discardableResult
    func enableBiometricProtection() async -> Bool {
        refreshBiometryAvailability()
        guard canUseBiometrics else {
            errorMessage = "finance.lock.biometric.unavailable".localized
            return false
        }

        guard await evaluateAuthentication(
            policy: .deviceOwnerAuthenticationWithBiometrics,
            reason: "finance.lock.biometric.enableReason".localized
        ) else {
            return false
        }

        do {
            try credentialStore.saveBiometricProtection()
            method = .biometrics
            isUnlocked = true
            errorMessage = nil
            Haptic.success()
            return true
        } catch {
            errorMessage = "finance.lock.error.save".localized
            return false
        }
    }

    @discardableResult
    func unlockWithDeviceAuthentication() async -> Bool {
        guard method == .biometrics else { return false }

        // This policy starts with the enrolled Face ID or Touch ID data and lets
        // iOS offer the device passcode if biometrics are locked out.
        let didAuthenticate = await evaluateAuthentication(
            policy: .deviceOwnerAuthentication,
            reason: "finance.lock.biometric.unlockReason".localized
        )
        if didAuthenticate {
            isUnlocked = true
            Haptic.success()
        }
        return didAuthenticate
    }

    @discardableResult
    func authorizeCurrentMethod() async -> Bool {
        switch method {
        case .none:
            return true
        case .pin:
            return isUnlocked
        case .biometrics:
            return await evaluateAuthentication(
                policy: .deviceOwnerAuthentication,
                reason: "finance.lock.settings.authorizeReason".localized
            )
        }
    }

    @discardableResult
    func disableProtection() -> Bool {
        do {
            try credentialStore.clearSecurely()
            method = .none
            isUnlocked = true
            errorMessage = nil
            Haptic.success()
            return true
        } catch {
            errorMessage = "finance.lock.error.save".localized
            return false
        }
    }

    func clearError() {
        errorMessage = nil
    }

    static func isValidPIN(_ pin: String) -> Bool {
        (4...6).contains(pin.count) && pin.allSatisfy { character in
            character.unicodeScalars.allSatisfy { (48...57).contains(Int($0.value)) }
        }
    }

    private func evaluateAuthentication(policy: LAPolicy, reason: String) async -> Bool {
        guard !isAuthenticating else { return false }

        let context = LAContext()
        context.localizedCancelTitle = "common.cancel".localized

        var policyError: NSError?
        guard context.canEvaluatePolicy(policy, error: &policyError) else {
            errorMessage = authenticationErrorMessage(policyError)
            return false
        }

        let attemptID = UUID()
        authenticationAttemptID = attemptID
        authenticationContext = context
        isAuthenticating = true
        errorMessage = nil

        do {
            let succeeded = try await context.evaluatePolicy(policy, localizedReason: reason)
            guard authenticationAttemptID == attemptID else { return false }
            finishAuthentication(attemptID: attemptID)
            if !succeeded {
                errorMessage = "finance.lock.error.failed".localized
            }
            return succeeded
        } catch {
            guard authenticationAttemptID == attemptID else { return false }
            finishAuthentication(attemptID: attemptID)
            errorMessage = authenticationErrorMessage(error as NSError)
            return false
        }
    }

    private func finishAuthentication(attemptID: UUID) {
        guard authenticationAttemptID == attemptID else { return }
        authenticationAttemptID = nil
        authenticationContext = nil
        isAuthenticating = false
    }

    private func authenticationErrorMessage(_ error: NSError?) -> String? {
        guard let error,
              error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return "finance.lock.error.unavailable".localized
        }

        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return nil
        case .biometryNotAvailable:
            return "finance.lock.biometric.unavailable".localized
        case .biometryNotEnrolled:
            return "finance.lock.biometric.notEnrolled".localized
        case .biometryLockout:
            return "finance.lock.biometric.lockout".localized
        case .passcodeNotSet:
            return "finance.lock.passcode.notSet".localized
        case .authenticationFailed:
            return "finance.lock.error.failed".localized
        default:
            return "finance.lock.error.unavailable".localized
        }
    }

    private static func securelyMatches(_ candidate: String, _ stored: String) -> Bool {
        let candidateBytes = Array(candidate.utf8)
        let storedBytes = Array(stored.utf8)
        guard candidateBytes.count == storedBytes.count else { return false }

        var difference: UInt8 = 0
        for index in candidateBytes.indices {
            difference |= candidateBytes[index] ^ storedBytes[index]
        }
        return difference == 0
    }
}

protocol FinanceLockCredentialStore: Sendable {
    func loadMethod() -> FinanceLockMethod?
    func loadPIN() -> String?
    func savePINProtection(_ pin: String) throws
    func saveBiometricProtection() throws
    func clearSecurely() throws
    func clear()
}

struct KeychainFinanceLockCredentialStore: FinanceLockCredentialStore {
    private let service = "com.lettertinit.Letter.finance-lock"
    private let configurationAccount = "configuration"

    func loadMethod() -> FinanceLockMethod? {
        loadConfiguration()?.method
    }

    func loadPIN() -> String? {
        let configuration = loadConfiguration()
        return configuration?.method == .pin ? configuration?.pin : nil
    }

    func savePINProtection(_ pin: String) throws {
        try saveConfiguration(StoredConfiguration(method: .pin, pin: pin))
    }

    func saveBiometricProtection() throws {
        try saveConfiguration(StoredConfiguration(method: .biometrics, pin: nil))
    }

    func clearSecurely() throws {
        try delete(account: configurationAccount)
    }

    func clear() {
        try? clearSecurely()
    }

    private func loadConfiguration() -> StoredConfiguration? {
        guard let data = read(account: configurationAccount) else { return nil }
        return try? JSONDecoder().decode(StoredConfiguration.self, from: data)
    }

    private func saveConfiguration(_ configuration: StoredConfiguration) throws {
        let data = try JSONEncoder().encode(configuration)
        try write(data, account: configurationAccount)
    }

    private func read(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    private func write(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw KeychainError(status: updateStatus)
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError(status: addStatus)
        }
    }

    private func delete(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError(status: status)
        }
    }

    private func baseQuery(account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }

    private struct StoredConfiguration: Codable {
        let method: FinanceLockMethod
        let pin: String?
    }
}

private struct KeychainError: Error {
    let status: OSStatus
}
