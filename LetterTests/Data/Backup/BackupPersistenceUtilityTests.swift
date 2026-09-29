import XCTest
@testable import Data
@testable import Domain

final class BackupArchiveCodecTests: XCTestCase {
    func test_encodeValidatedAndDecodeValidated_roundTripArchiveAndSummary() throws {
        let archive = makeArchive(
            exportedAt: date(1_000),
            finance: makeFinanceBackup(transactions: [makeTransactionBackup()])
        )
        let codec = BackupArchiveCodec()

        let data = try codec.encodeValidated(archive)
        let decoded = try codec.decodeValidated(data)

        XCTAssertEqual(decoded.schemaVersion, BackupArchive.currentSchemaVersion)
        XCTAssertEqual(decoded.exportedAt, archive.exportedAt)
        XCTAssertEqual(decoded.finance.transactions.count, 1)
        XCTAssertEqual(decoded.summary.transactionCount, 1)
        XCTAssertEqual(decoded.summary.budgetCount, 0)
        XCTAssertEqual(decoded.summary.habitCount, 0)
    }

    func test_decodeValidated_throwsInvalidDataForMalformedJSON() {
        let data = Data("not json".utf8)

        XCTAssertThrowsError(try BackupArchiveCodec().decodeValidated(data)) { error in
            XCTAssertBackupError(error, equals: .invalidData)
        }
    }

    func test_encodeValidated_throwsUnsupportedVersionForArchiveSchemaMismatch() {
        let archive = makeArchive(schemaVersion: BackupArchive.currentSchemaVersion + 1)

        XCTAssertThrowsError(try BackupArchiveCodec().encodeValidated(archive)) { error in
            XCTAssertBackupError(
                error,
                equals: .unsupportedSchemaVersion(BackupArchive.currentSchemaVersion + 1)
            )
        }
    }

    func test_encodeValidated_throwsUnsupportedVersionForFinanceSchemaMismatch() {
        let archive = makeArchive(finance: makeFinanceBackup(schemaVersion: FinanceBackup.schemaVersion + 1))

        XCTAssertThrowsError(try BackupArchiveCodec().encodeValidated(archive)) { error in
            XCTAssertBackupError(
                error,
                equals: .unsupportedSchemaVersion(FinanceBackup.schemaVersion + 1)
            )
        }
    }

    func test_encodeValidated_mapsInvalidHabitBackupToInvalidData() {
        let duplicateID = uuid(20)
        let firstHabit = Habit(name: "One")
        firstHabit.id = duplicateID
        let secondHabit = Habit(name: "Two")
        secondHabit.id = duplicateID
        let archive = makeArchive(
            habits: HabitBackup(profile: nil, habits: [firstHabit, secondHabit])
        )

        XCTAssertThrowsError(try BackupArchiveCodec().encodeValidated(archive)) { error in
            XCTAssertBackupError(error, equals: .invalidData)
        }
    }
}

final class BackupFileReaderTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LetterBackupFileReaderTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func test_readData_returnsFileContents() throws {
        let url = temporaryDirectory.appendingPathComponent("backup.json")
        let data = Data("backup".utf8)
        try data.write(to: url)

        XCTAssertEqual(try BackupFileReader().readData(from: url), data)
    }

    func test_readData_mapsUnreadableFileToInvalidData() {
        let url = temporaryDirectory.appendingPathComponent("missing.json")

        XCTAssertThrowsError(try BackupFileReader().readData(from: url)) { error in
            XCTAssertBackupError(error, equals: .invalidData)
        }
    }
}

final class FinanceBackupSettingsStoreTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "LetterFinanceBackupSettingsTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func test_loadEarliestMonth_defaultsToCurrentMonthStart() {
        let now = date(2_000_000)
        let store = FinanceBackupSettingsStore(userDefaults: defaults, now: { now })

        XCTAssertEqual(store.loadEarliestMonth(), FinanceMonth(now).startDate)
    }

    func test_restoreEarliestMonth_persistsStartOfMonth() {
        let restored = date(3_000_000)
        let store = FinanceBackupSettingsStore(userDefaults: defaults)

        store.restoreEarliestMonth(restored)

        XCTAssertEqual(store.loadEarliestMonth(), FinanceMonth(restored).startDate)
    }

    func test_restoreEarliestMonth_ignoresNilAndClearRemovesStoredMonth() {
        let now = date(4_000_000)
        let restored = date(5_000_000)
        let store = FinanceBackupSettingsStore(userDefaults: defaults, now: { now })
        store.restoreEarliestMonth(restored)

        store.restoreEarliestMonth(nil)

        XCTAssertEqual(store.loadEarliestMonth(), FinanceMonth(restored).startDate)

        store.clearEarliestMonth()

        XCTAssertEqual(store.loadEarliestMonth(), FinanceMonth(now).startDate)
    }
}

private func makeArchive(
    schemaVersion: Int = BackupArchive.currentSchemaVersion,
    exportedAt: Date = date(100),
    earliestMonth: Date? = nil,
    finance: FinanceBackup = makeFinanceBackup(),
    habits: HabitBackup = makeHabitBackup(),
    speechProviderSettings: SpeechProviderSettingsBackup? = nil
) -> BackupArchive {
    BackupArchive(
        schemaVersion: schemaVersion,
        exportedAt: exportedAt,
        earliestMonth: earliestMonth,
        finance: finance,
        habits: habits,
        speechProviderSettings: speechProviderSettings
    )
}

private func makeFinanceBackup(
    schemaVersion: Int = FinanceBackup.schemaVersion,
    transactions: [TransactionBackup] = [],
    budgets: [BudgetBackup] = [],
    netWorthPlanItems: [NetWorthPlanItemBackup] = [],
    netWorthSnapshots: [NetWorthSnapshotBackup] = [],
    balanceMonths: [BalanceMonthBackup]? = []
) -> FinanceBackup {
    FinanceBackup(
        schemaVersion: schemaVersion,
        backupDate: date(200),
        transactions: transactions,
        budgets: budgets,
        netWorthPlanItems: netWorthPlanItems,
        netWorthSnapshots: netWorthSnapshots,
        balanceMonths: balanceMonths
    )
}

private func makeHabitBackup() -> HabitBackup {
    HabitBackup(profile: nil, habits: [])
}

private func makeTransactionBackup() -> TransactionBackup {
    TransactionBackup(
        id: uuid(1),
        note: "Note",
        type: .income,
        category: .salary,
        method: .banking,
        amount: 12,
        occurredAt: date(400),
        createAt: date(401)
    )
}

private func uuid(_ value: Int) -> UUID {
    UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
}

private func date(_ value: TimeInterval) -> Date {
    Date(timeIntervalSince1970: value)
}

private func XCTAssertBackupError(
    _ error: Error,
    equals expected: BackupError,
    file: StaticString = #filePath,
    line: UInt = #line
) {
    guard let error = error as? BackupError else {
        XCTFail("Expected BackupError, got \(error)", file: file, line: line)
        return
    }

    switch (error, expected) {
    case (.invalidData, .invalidData),
         (.restoreFailed, .restoreFailed):
        return
    case let (.unsupportedSchemaVersion(actual), .unsupportedSchemaVersion(expected)):
        XCTAssertEqual(actual, expected, file: file, line: line)
    default:
        XCTFail("Expected \(expected), got \(error)", file: file, line: line)
    }
}
