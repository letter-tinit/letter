import Foundation
import LocalAuthentication
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpFinanceLockRepositoryTests: XCTestCase {
    func test_savePINProtection_persistsPINConfiguration() throws {
        let repository = ImpFinanceLockRepository(keychainStore: InMemoryFinanceLockKeychainStore())

        try repository.savePINProtection("123456")

        XCTAssertEqual(repository.loadMethod(), .pin)
        XCTAssertEqual(repository.loadPIN(), "123456")
    }

    func test_saveBiometricProtection_persistsBiometricConfigurationWithoutPIN() throws {
        let repository = ImpFinanceLockRepository(keychainStore: InMemoryFinanceLockKeychainStore())

        try repository.savePINProtection("1234")
        try repository.saveBiometricProtection()

        XCTAssertEqual(repository.loadMethod(), .biometrics)
        XCTAssertNil(repository.loadPIN())
    }

    func test_clearProtection_removesStoredConfiguration() throws {
        let repository = ImpFinanceLockRepository(keychainStore: InMemoryFinanceLockKeychainStore())
        try repository.savePINProtection("1234")

        try repository.clearProtection()

        XCTAssertNil(repository.loadMethod())
        XCTAssertNil(repository.loadPIN())
    }

    func test_loadConfiguration_ignoresInvalidStoredData() {
        let store = InMemoryFinanceLockKeychainStore()
        let repository = ImpFinanceLockRepository(keychainStore: store)
        try? store.write(Foundation.Data("invalid".utf8), account: "configuration")

        XCTAssertNil(repository.loadMethod())
        XCTAssertNil(repository.loadPIN())
    }

    func test_mapAuthenticationError_mapsKnownLocalAuthenticationCodes() {
        let repository = ImpFinanceLockRepository(keychainStore: InMemoryFinanceLockKeychainStore())

        XCTAssertEqual(
            repository.mapAuthenticationError(NSError(domain: LAError.errorDomain, code: LAError.userCancel.rawValue)),
            .authenticationCancelled
        )
        XCTAssertEqual(
            repository.mapAuthenticationError(NSError(domain: LAError.errorDomain, code: LAError.biometryNotEnrolled.rawValue)),
            .biometricsNotEnrolled
        )
        XCTAssertEqual(
            repository.mapAuthenticationError(NSError(domain: LAError.errorDomain, code: LAError.biometryLockout.rawValue)),
            .biometricsLocked
        )
        XCTAssertEqual(repository.mapAuthenticationError(nil), .unavailable)
    }
}

private final class InMemoryFinanceLockKeychainStore: FinanceLockKeychainStore {
    private var storage: [String: Foundation.Data] = [:]

    func read(account: String) -> Foundation.Data? {
        storage[account]
    }

    func write(_ data: Foundation.Data, account: String) throws {
        storage[account] = data
    }

    func delete(account: String) throws {
        storage[account] = nil
    }
}
