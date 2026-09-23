import Foundation
import XCTest
@testable import Domain

@MainActor
final class NetWorthUseCaseTests: XCTestCase {
    func test_load_returnsRepositoryData() throws {
        let item = NetWorthPlanItem(category: .cashAndCashEquivalents, name: "Cash", displayOrder: 1)
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))
        let repository = FakeNetWorthRepository(data: NetWorthData(planItems: [item], snapshots: [snapshot]))
        let useCase = ImpNetWorthUseCase(repository: repository)

        let data = try useCase.load()

        XCTAssertEqual(data.planItems, [item])
        XCTAssertEqual(data.snapshots, [snapshot])
    }

    func test_createSnapshot_savesStartOfMonthSnapshot() throws {
        let repository = FakeNetWorthRepository()
        let useCase = ImpNetWorthUseCase(repository: repository)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!

        try useCase.createSnapshot(for: Date(timeIntervalSince1970: 2_678_400), calendar: calendar)

        XCTAssertEqual(repository.savedSnapshots.count, 1)
        XCTAssertEqual(
            repository.savedSnapshots[0].asOfDate,
            calendar.date(from: DateComponents(year: 1970, month: 2, day: 1))
        )
    }

    func test_addItem_savesPlanItemAndSnapshotAmount() throws {
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))
        let existing = [
            NetWorthPlanItem(category: .cashAndCashEquivalents, name: "Wallet", displayOrder: 1)
        ]
        let repository = FakeNetWorthRepository()
        let useCase = ImpNetWorthUseCase(repository: repository)

        try useCase.addItem(
            ValidatedNetWorthItemInput(
                category: .cashAndCashEquivalents,
                name: "Bank",
                amount: 500
            ),
            to: snapshot,
            existingItems: existing
        )

        XCTAssertEqual(repository.savedPlanItems.count, 1)
        XCTAssertEqual(repository.savedPlanItems[0].displayOrder, 2)
        XCTAssertEqual(snapshot.amount(for: repository.savedPlanItems[0]), 500)
        XCTAssertEqual(repository.savedSnapshots, [snapshot])
    }

    func test_updateItem_assignsNextOrderWhenCategoryChanges() throws {
        let item = NetWorthPlanItem(category: .cashAndCashEquivalents, name: "Cash", displayOrder: 1)
        let existing = [
            NetWorthPlanItem(category: .longTermDebt, name: "Mortgage", displayOrder: 1)
        ]
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))
        let repository = FakeNetWorthRepository()
        let useCase = ImpNetWorthUseCase(repository: repository)

        try useCase.updateItem(
            item,
            input: ValidatedNetWorthItemInput(category: .longTermDebt, name: "Loan", amount: 1000),
            snapshot: snapshot,
            existingItems: existing
        )

        XCTAssertEqual(item.category, .longTermDebt)
        XCTAssertEqual(item.name, "Loan")
        XCTAssertEqual(item.displayOrder, 2)
        XCTAssertEqual(snapshot.amount(for: item), 1000)
        XCTAssertEqual(repository.savedPlanItems, [item])
        XCTAssertEqual(repository.savedSnapshots, [snapshot])
    }

    func test_toggleEditingLock_flipsAndSavesSnapshot() throws {
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))
        let repository = FakeNetWorthRepository()
        let useCase = ImpNetWorthUseCase(repository: repository)

        try useCase.toggleEditingLock(for: snapshot)

        XCTAssertTrue(snapshot.isLocked)
        XCTAssertEqual(repository.savedSnapshots, [snapshot])
    }

    func test_deleteItemAndSnapshot_forwardIDsToRepository() throws {
        let item = NetWorthPlanItem(category: .financialAssets, name: "ETF", displayOrder: 1)
        let snapshot = NetWorthSnapshot(asOfDate: Date(timeIntervalSince1970: 0))
        let repository = FakeNetWorthRepository()
        let useCase = ImpNetWorthUseCase(repository: repository)

        try useCase.deleteItem(item)
        try useCase.deleteSnapshot(snapshot)

        XCTAssertEqual(repository.deletedPlanItemIDs, [item.id])
        XCTAssertEqual(repository.deletedSnapshotIDs, [snapshot.id])
    }
}

@MainActor
private final class FakeNetWorthRepository: NetWorthRepository {
    var data: NetWorthData
    var savedSnapshots: [NetWorthSnapshot] = []
    var savedPlanItems: [NetWorthPlanItem] = []
    var deletedPlanItemIDs: [UUID] = []
    var deletedSnapshotIDs: [UUID] = []

    init(data: NetWorthData = NetWorthData(planItems: [], snapshots: [])) {
        self.data = data
    }

    func fetchData() throws -> NetWorthData {
        data
    }

    func saveSnapshot(_ snapshot: NetWorthSnapshot) throws {
        savedSnapshots.append(snapshot)
    }

    func savePlanItem(_ item: NetWorthPlanItem) throws {
        savedPlanItems.append(item)
    }

    func deletePlanItem(id: UUID) throws {
        deletedPlanItemIDs.append(id)
    }

    func deleteSnapshot(id: UUID) throws {
        deletedSnapshotIDs.append(id)
    }
}
