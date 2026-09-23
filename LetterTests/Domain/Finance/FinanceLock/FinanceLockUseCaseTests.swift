import XCTest
@testable import Domain

@MainActor
final class FinanceLockUseCaseTests: XCTestCase {
    func test_loadMethod_returnsNoneWhenPINMethodHasNoStoredPINAndClearsProtection() {
        let repository = FakeFinanceLockRepository(method: .pin, pin: nil)
        let useCase = ImpFinanceLockUseCase(repository: repository)

        let method = useCase.loadMethod()

        XCTAssertEqual(method, .none)
        XCTAssertEqual(repository.clearProtectionCallCount, 1)
    }

    func test_verifyPIN_succeedsWhenStoredPINMatches() throws {
        let repository = FakeFinanceLockRepository(method: .pin, pin: "1234")
        let useCase = ImpFinanceLockUseCase(repository: repository)

        XCTAssertNoThrow(try useCase.verifyPIN("1234"))
    }

    func test_verifyPIN_throwsIncorrectPINWhenPINDoesNotMatch() {
        let repository = FakeFinanceLockRepository(method: .pin, pin: "1234")
        let useCase = ImpFinanceLockUseCase(repository: repository)

        XCTAssertThrowsError(try useCase.verifyPIN("9999")) { error in
            XCTAssertEqual(error as? FinanceLockError, .incorrectPIN)
        }
    }

    func test_configurePIN_savesValidPIN() throws {
        let repository = FakeFinanceLockRepository()
        let useCase = ImpFinanceLockUseCase(repository: repository)

        try useCase.configurePIN("123456")

        XCTAssertEqual(repository.savedPINs, ["123456"])
        XCTAssertEqual(repository.method, .pin)
    }

    func test_configurePIN_throwsInvalidPIN() {
        let repository = FakeFinanceLockRepository()
        let useCase = ImpFinanceLockUseCase(repository: repository)

        XCTAssertThrowsError(try useCase.configurePIN("12AB")) { error in
            XCTAssertEqual(error as? FinanceLockError, .invalidPIN)
        }
    }

    func test_enableBiometricProtection_authenticatesAndSavesWhenAvailable() async throws {
        let repository = FakeFinanceLockRepository(
            biometryStatus: FinanceBiometryStatus(biometry: .faceID, isAvailable: true)
        )
        let useCase = ImpFinanceLockUseCase(repository: repository)

        try await useCase.enableBiometricProtection(reason: "Unlock")

        XCTAssertEqual(repository.authenticationRequests, [.biometrics])
        XCTAssertEqual(repository.method, .biometrics)
    }

    func test_enableBiometricProtection_throwsWhenUnavailable() async {
        let repository = FakeFinanceLockRepository(
            biometryStatus: FinanceBiometryStatus(biometry: .unavailable, isAvailable: false)
        )
        let useCase = ImpFinanceLockUseCase(repository: repository)

        do {
            try await useCase.enableBiometricProtection(reason: "Unlock")
            XCTFail("Expected biometricsUnavailable")
        } catch {
            XCTAssertEqual(error as? FinanceLockError, .biometricsUnavailable)
        }
    }

    func test_authorizeCurrentMethod_returnsExpectedAuthorization() async throws {
        let repository = FakeFinanceLockRepository()
        let useCase = ImpFinanceLockUseCase(repository: repository)

        let noneAuthorized = try await useCase.authorizeCurrentMethod(.none, isUnlocked: false, reason: "")
        let lockedPINAuthorized = try await useCase.authorizeCurrentMethod(.pin, isUnlocked: false, reason: "")
        let unlockedPINAuthorized = try await useCase.authorizeCurrentMethod(.pin, isUnlocked: true, reason: "")
        let biometricAuthorized = try await useCase.authorizeCurrentMethod(.biometrics, isUnlocked: false, reason: "")

        XCTAssertTrue(noneAuthorized)
        XCTAssertFalse(lockedPINAuthorized)
        XCTAssertTrue(unlockedPINAuthorized)
        XCTAssertTrue(biometricAuthorized)
        XCTAssertEqual(repository.authenticationRequests, [.deviceOwner])
    }

    func test_disableProtection_clearsRepositoryProtection() throws {
        let repository = FakeFinanceLockRepository(method: .pin, pin: "1234")
        let useCase = ImpFinanceLockUseCase(repository: repository)

        try useCase.disableProtection()

        XCTAssertEqual(repository.clearProtectionCallCount, 1)
        XCTAssertEqual(repository.method, FinanceLockMethod.none)
        XCTAssertNil(repository.pin)
    }
}

@MainActor
private final class FakeFinanceLockRepository: FinanceLockRepository {
    var method: FinanceLockMethod?
    var pin: String?
    var status: FinanceBiometryStatus
    var savedPINs: [String] = []
    var authenticationRequests: [FinanceAuthenticationPolicy] = []
    var clearProtectionCallCount = 0
    var shouldFailSave = false
    var shouldFailAuthentication = false

    init(
        method: FinanceLockMethod? = nil,
        pin: String? = nil,
        biometryStatus: FinanceBiometryStatus = FinanceBiometryStatus(biometry: .faceID, isAvailable: true)
    ) {
        self.method = method
        self.pin = pin
        status = biometryStatus
    }

    func loadMethod() -> FinanceLockMethod? {
        method
    }

    func loadPIN() -> String? {
        pin
    }

    func savePINProtection(_ pin: String) throws {
        if shouldFailSave { throw FinanceLockError.saveFailed }
        self.pin = pin
        method = .pin
        savedPINs.append(pin)
    }

    func saveBiometricProtection() throws {
        if shouldFailSave { throw FinanceLockError.saveFailed }
        method = .biometrics
    }

    func clearProtection() throws {
        if shouldFailSave { throw FinanceLockError.saveFailed }
        method = FinanceLockMethod.none
        pin = nil
        clearProtectionCallCount += 1
    }

    func biometryStatus() -> FinanceBiometryStatus {
        status
    }

    func authenticate(
        policy: FinanceAuthenticationPolicy,
        reason: String
    ) async throws {
        if shouldFailAuthentication { throw FinanceLockError.authenticationFailed }
        authenticationRequests.append(policy)
    }

    func cancelAuthentication() {}
}
