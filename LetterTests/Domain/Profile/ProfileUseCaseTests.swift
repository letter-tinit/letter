import Foundation
import XCTest
@testable import Domain

@MainActor
final class ProfileUseCaseTests: XCTestCase {
    func test_loadProfile_returnsExistingProfileWithoutCreatingDefault() throws {
        let profile = makeProfile(displayName: "Existing")
        let repository = FakeHabitRepository(profile: profile)
        let useCase = ImpProfileUseCase(
            repository: repository,
            backupRepository: FakeBackupRepository()
        )

        let loaded = try useCase.loadProfile()

        XCTAssertEqual(loaded.id, profile.id)
        XCTAssertEqual(loaded.displayName, "Existing")
        XCTAssertEqual(repository.createdDefaultProfileCount, 0)
    }

    func test_loadProfile_createsDefaultWhenMissing() throws {
        let repository = FakeHabitRepository()
        let useCase = ImpProfileUseCase(
            repository: repository,
            backupRepository: FakeBackupRepository()
        )

        let loaded = try useCase.loadProfile()

        XCTAssertEqual(loaded.displayName, "Tester")
        XCTAssertTrue(loaded.weekStartsOnMonday)
        XCTAssertEqual(loaded.colorScheme, .light)
        XCTAssertEqual(repository.createdDefaultProfileCount, 1)
    }

    func test_updatePreferences_persistThroughRepository() throws {
        let profile = makeProfile(weekStartsOnMonday: true, colorScheme: .light)
        let repository = FakeHabitRepository(profile: profile)
        let useCase = ImpProfileUseCase(
            repository: repository,
            backupRepository: FakeBackupRepository()
        )

        let weekStart = try useCase.updateWeekStartsOnMonday(false)
        let color = try useCase.updateColorScheme(.dark)

        XCTAssertEqual(repository.updatedWeekStartsOnMondayInputs, [false])
        XCTAssertFalse(weekStart.weekStartsOnMonday)
        XCTAssertEqual(repository.updatedColorSchemeInputs, [.dark])
        XCTAssertEqual(color.colorScheme, .dark)
    }

    func test_updateProfile_persistsDisplayNameAndAvatarData() throws {
        let profile = makeProfile(displayName: "Old")
        let repository = FakeHabitRepository(profile: profile)
        let useCase = ImpProfileUseCase(
            repository: repository,
            backupRepository: FakeBackupRepository()
        )
        let original = Data([1, 2, 3])
        let resized = Data([4, 5])

        let updated = try useCase.updateProfile(
            displayName: "New",
            avatarOriginalData: original,
            avatarData: resized
        )

        XCTAssertEqual(repository.updatedProfileInputs.first?.displayName, "New")
        XCTAssertEqual(repository.updatedProfileInputs.first?.avatarOriginalData, original)
        XCTAssertEqual(repository.updatedProfileInputs.first?.avatarData, resized)
        XCTAssertEqual(updated.displayName, "New")
        XCTAssertEqual(updated.avatarOriginalData, original)
        XCTAssertEqual(updated.avatarData, resized)
    }

    func test_updateProfile_throwsWhenProfileIsMissing() {
        let useCase = ImpProfileUseCase(
            repository: FakeHabitRepository(),
            backupRepository: FakeBackupRepository()
        )

        XCTAssertThrowsError(try useCase.updateColorScheme(.dark)) { error in
            XCTAssertEqual(error as? ProfileUseCaseError, .profileNotFound)
        }
    }

    func test_backupOperationsForwardToBackupRepository() throws {
        let backup = FakeBackupRepository()
        let useCase = ImpProfileUseCase(
            repository: FakeHabitRepository(profile: makeProfile()),
            backupRepository: backup
        )
        let url = URL(fileURLWithPath: "/tmp/letter-backup.json")
        let restoreData = Data([9, 8, 7])

        let exported = try useCase.exportBackup()
        let inspected = try useCase.inspectBackup(at: url)
        try useCase.restoreBackup(restoreData)
        try useCase.clearAllData()

        XCTAssertEqual(exported, backup.backupFile)
        XCTAssertEqual(inspected, backup.backupImport)
        XCTAssertEqual(backup.inspectedURLs, [url])
        XCTAssertEqual(backup.restoredData, [restoreData])
        XCTAssertEqual(backup.clearAllDataCount, 1)
    }

    private func makeProfile(
        id: UUID = UUID(),
        displayName: String = "Tester",
        avatarOriginalData: Data? = nil,
        avatarData: Data? = nil,
        weekStartsOnMonday: Bool = true,
        colorScheme: AppColorScheme = .light
    ) -> UserProfileSnapshot {
        UserProfileSnapshot(
            id: id,
            displayName: displayName,
            avatarOriginalData: avatarOriginalData,
            avatarData: avatarData,
            weekStartsOnMonday: weekStartsOnMonday,
            colorScheme: colorScheme
        )
    }
}

@MainActor
private final class FakeBackupRepository: BackupRepository {
    let backupFile = BackupFile(data: Data([1, 2, 3]))
    let backupImport = BackupImport(
        data: Data([4, 5, 6]),
        summary: BackupSummary(
            exportedAt: Date(timeIntervalSince1970: 1_700_000_000),
            transactionCount: 1,
            budgetCount: 2,
            netWorthSnapshotCount: 3,
            habitCount: 4,
            habitEntryCount: 5
        )
    )
    var inspectedURLs: [URL] = []
    var restoredData: [Data] = []
    var clearAllDataCount = 0

    func exportBackup() throws -> BackupFile {
        backupFile
    }

    func inspectBackup(at url: URL) throws -> BackupImport {
        inspectedURLs.append(url)
        return backupImport
    }

    func restoreBackup(_ data: Data) throws {
        restoredData.append(data)
    }

    func clearAllData() throws {
        clearAllDataCount += 1
    }
}
