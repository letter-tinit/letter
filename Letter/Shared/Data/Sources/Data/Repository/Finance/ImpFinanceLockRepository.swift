import Foundation
import LocalAuthentication
import Security
import Domain
import Utility

@MainActor
public final class ImpFinanceLockRepository: FinanceLockRepository {
    private let service = "com.lettertinit.Letter.finance-lock"
    private let configurationAccount = "configuration"
    private let keychainStore: FinanceLockKeychainStore
    private var authenticationContext: LAContext?

    public init() {
        keychainStore = SecurityFinanceLockKeychainStore(service: service)
    }

    init(keychainStore: FinanceLockKeychainStore) {
        self.keychainStore = keychainStore
    }

    public func loadMethod() -> FinanceLockMethod? {
        loadConfiguration()?.method
    }

    public func loadPIN() -> String? {
        let configuration = loadConfiguration()
        return configuration?.method == .pin ? configuration?.pin : nil
    }

    public func savePINProtection(_ pin: String) throws {
        try saveConfiguration(StoredConfiguration(method: .pin, pin: pin))
    }

    public func saveBiometricProtection() throws {
        try saveConfiguration(StoredConfiguration(method: .biometrics, pin: nil))
    }

    public func clearProtection() throws {
        try delete(account: configurationAccount)
    }

    public func biometryStatus() -> FinanceBiometryStatus {
        let context = LAContext()
        var error: NSError?
        let isAvailable = context.canEvaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            error: &error
        )

        let biometry: FinanceBiometry = switch context.biometryType {
        case .touchID: .touchID
        case .faceID: .faceID
        case .opticID: .other
        case .none: .unavailable
        @unknown default: .other
        }
        return FinanceBiometryStatus(biometry: biometry, isAvailable: isAvailable)
    }

    public func authenticate(
        policy: FinanceAuthenticationPolicy,
        reason: String
    ) async throws {
        let context = LAContext()
        context.localizedCancelTitle = "common.cancel".localized
        authenticationContext?.invalidate()
        authenticationContext = context
        defer {
            if authenticationContext === context {
                authenticationContext = nil
            }
        }

        let localPolicy: LAPolicy = switch policy {
        case .biometrics: .deviceOwnerAuthenticationWithBiometrics
        case .deviceOwner: .deviceOwnerAuthentication
        }
        var policyError: NSError?
        guard context.canEvaluatePolicy(localPolicy, error: &policyError) else {
            throw mapAuthenticationError(policyError)
        }

        do {
            guard try await context.evaluatePolicy(localPolicy, localizedReason: reason) else {
                throw FinanceLockError.authenticationFailed
            }
        } catch let error as FinanceLockError {
            throw error
        } catch {
            throw mapAuthenticationError(error as NSError)
        }
    }

    public func cancelAuthentication() {
        authenticationContext?.invalidate()
        authenticationContext = nil
    }
}

extension ImpFinanceLockRepository {
    func loadConfiguration() -> StoredConfiguration? {
        guard let data = keychainStore.read(account: configurationAccount) else { return nil }
        return try? JSONDecoder().decode(StoredConfiguration.self, from: data)
    }

    func saveConfiguration(_ configuration: StoredConfiguration) throws {
        try keychainStore.write(JSONEncoder().encode(configuration), account: configurationAccount)
    }

    public func read(account: String) -> Data? {
        keychainStore.read(account: account)
    }

    public func write(_ data: Data, account: String) throws {
        try keychainStore.write(data, account: account)
    }

    public func delete(account: String) throws {
        try keychainStore.delete(account: account)
    }

    public func baseQuery(account: String) -> [String: Any] {
        SecurityFinanceLockKeychainStore.baseQuery(service: service, account: account)
    }

    func mapAuthenticationError(_ error: NSError?) -> FinanceLockError {
        guard let error,
              error.domain == LAError.errorDomain,
              let code = LAError.Code(rawValue: error.code) else {
            return .unavailable
        }

        switch code {
        case .userCancel, .appCancel, .systemCancel:
            return .authenticationCancelled
        case .biometryNotAvailable:
            return .biometricsUnavailable
        case .biometryNotEnrolled:
            return .biometricsNotEnrolled
        case .biometryLockout:
            return .biometricsLocked
        case .passcodeNotSet:
            return .passcodeNotSet
        case .authenticationFailed:
            return .authenticationFailed
        default:
            return .unavailable
        }
    }

    struct StoredConfiguration: Codable {
        let method: FinanceLockMethod
        let pin: String?
    }

    struct KeychainError: Error {
        let status: OSStatus
    }
}

protocol FinanceLockKeychainStore {
    func read(account: String) -> Data?
    func write(_ data: Data, account: String) throws
    func delete(account: String) throws
}

private struct SecurityFinanceLockKeychainStore: FinanceLockKeychainStore {
    let service: String

    func read(account: String) -> Data? {
        var query = Self.baseQuery(service: service, account: account)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else {
            return nil
        }
        return result as? Data
    }

    func write(_ data: Data, account: String) throws {
        let query = Self.baseQuery(service: service, account: account)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else {
            throw ImpFinanceLockRepository.KeychainError(status: updateStatus)
        }

        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        let addStatus = SecItemAdd(item as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw ImpFinanceLockRepository.KeychainError(status: addStatus)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(Self.baseQuery(service: service, account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw ImpFinanceLockRepository.KeychainError(status: status)
        }
    }

    static func baseQuery(service: String, account: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: false
        ]
    }
}
