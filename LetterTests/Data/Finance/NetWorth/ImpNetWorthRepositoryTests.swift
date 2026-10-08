import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpNetWorthRepositoryTests: XCTestCase {
    func test_savePlanItem_roundTripsAndSortsByDisplayOrder() throws {
        let repository = try makeRepository()
        let later = NetWorthPlanItem(
            id: uuid(1),
            category: .investment,
            name: "Brokerage",
            displayOrder: 2
        )
        let earlier = NetWorthPlanItem(
            id: uuid(2),
            category: .cashAndBank,
            name: "Cash",
            displayOrder: 1
        )

        try repository.savePlanItem(later)
        try repository.savePlanItem(earlier)

        let data = try repository.fetchData()
        XCTAssertEqual(data.planItems.map(\.id), [earlier.id, later.id])
        XCTAssertEqual(data.planItems.map(\.name), ["Cash", "Brokerage"])
    }

    func test_saveSnapshot_roundTripsValuesLinkedToPlanItems() throws {
        let repository = try makeRepository()
        let cash = NetWorthPlanItem(
            id: uuid(3),
            category: .cashAndBank,
            name: "Cash",
            displayOrder: 1
        )
        let debt = NetWorthPlanItem(
            id: uuid(4),
            category: .shortTermDebt,
            name: "Card",
            displayOrder: 2
        )
        try repository.savePlanItem(cash)
        try repository.savePlanItem(debt)

        let snapshot = NetWorthSnapshot(id: uuid(5), asOfDate: date(200))
        snapshot.isLocked = true
        let cashValue = NetWorthValue(id: uuid(6), amount: 1_000)
        cashValue.planItem = cash
        cashValue.snapshot = snapshot
        let debtValue = NetWorthValue(id: uuid(7), amount: 100)
        debtValue.planItem = debt
        debtValue.snapshot = snapshot
        snapshot.values = [cashValue, debtValue]

        try repository.saveSnapshot(snapshot)

        let data = try repository.fetchData()
        let fetchedSnapshot = try XCTUnwrap(data.snapshots.first)
        XCTAssertEqual(fetchedSnapshot.id, snapshot.id)
        XCTAssertEqual(fetchedSnapshot.asOfDate, date(200))
        XCTAssertEqual(fetchedSnapshot.isLocked, true)
        XCTAssertEqual(fetchedSnapshot.amount(for: data.planItems.first { $0.id == cash.id }!), 1_000)
        XCTAssertEqual(fetchedSnapshot.amount(for: data.planItems.first { $0.id == debt.id }!), 100)
        XCTAssertTrue(fetchedSnapshot.values.allSatisfy { $0.snapshot === fetchedSnapshot })
    }

    func test_fetchData_sortsSnapshotsByDateDescending() throws {
        let repository = try makeRepository()
        let older = NetWorthSnapshot(id: uuid(8), asOfDate: date(100))
        let newer = NetWorthSnapshot(id: uuid(9), asOfDate: date(200))
        try repository.saveSnapshot(older)
        try repository.saveSnapshot(newer)

        XCTAssertEqual(try repository.fetchData().snapshots.map(\.id), [newer.id, older.id])
    }

    func test_saveSnapshot_replacesExistingValues() throws {
        let repository = try makeRepository()
        let item = NetWorthPlanItem(
            id: uuid(10),
            category: .cashAndBank,
            name: "Cash",
            displayOrder: 1
        )
        try repository.savePlanItem(item)
        let original = NetWorthSnapshot(id: uuid(11), asOfDate: date(100))
        original.setAmount(10, for: item)
        try repository.saveSnapshot(original)

        let updated = NetWorthSnapshot(id: original.id, asOfDate: date(300))
        updated.isLocked = true
        updated.setAmount(25, for: item)
        try repository.saveSnapshot(updated)

        let data = try repository.fetchData()
        let fetched = try XCTUnwrap(data.snapshots.first)
        XCTAssertEqual(data.snapshots.count, 1)
        XCTAssertEqual(fetched.asOfDate, date(300))
        XCTAssertEqual(fetched.isLocked, true)
        XCTAssertEqual(fetched.values.count, 1)
        XCTAssertEqual(fetched.amount(for: data.planItems[0]), 25)
    }

    func test_deletePlanItemAndSnapshot_removeMatchingRecords() throws {
        let repository = try makeRepository()
        let item = NetWorthPlanItem(
            id: uuid(12),
            category: .investment,
            name: "Fund",
            displayOrder: 1
        )
        let snapshot = NetWorthSnapshot(id: uuid(13), asOfDate: date(100))
        try repository.savePlanItem(item)
        try repository.saveSnapshot(snapshot)

        try repository.deletePlanItem(id: item.id)
        try repository.deleteSnapshot(id: snapshot.id)

        let data = try repository.fetchData()
        XCTAssertTrue(data.planItems.isEmpty)
        XCTAssertTrue(data.snapshots.isEmpty)
    }

    private func makeRepository() throws -> ImpNetWorthRepository {
        let container = try FinanceRepositoryTestSupport.makeNetWorthContainer()
        return ImpNetWorthRepository(modelContext: ModelContext(container))
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
