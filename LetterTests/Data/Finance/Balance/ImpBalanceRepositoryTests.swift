import Foundation
import SwiftData
import XCTest
@testable import Data
@testable import Domain

@MainActor
final class ImpBalanceRepositoryTests: XCTestCase {
    func test_saveTransaction_roundTripsAndSortsByOccurredAtDescending() throws {
        let repository = try makeRepository()
        let older = makeTransaction(
            id: uuid(1),
            note: "Older",
            amount: 10,
            occurredAt: date(100)
        )
        let newer = makeTransaction(
            id: uuid(2),
            note: "Newer",
            amount: 20,
            occurredAt: date(200)
        )

        try repository.saveTransaction(older)
        try repository.saveTransaction(newer)

        XCTAssertEqual(try repository.fetchTransactions(), [newer, older])
    }

    func test_saveTransaction_updatesExistingRecordWithSameID() throws {
        let repository = try makeRepository()
        let id = uuid(3)
        try repository.saveTransaction(makeTransaction(id: id, note: "Before", amount: 12, occurredAt: date(100)))

        let updated = makeTransaction(id: id, note: "After", amount: 34, occurredAt: date(300))
        try repository.saveTransaction(updated)

        XCTAssertEqual(try repository.fetchTransactions(), [updated])
    }

    func test_deleteTransaction_removesMatchingRecord() throws {
        let repository = try makeRepository()
        let deleted = makeTransaction(id: uuid(4), note: "Delete", amount: 10, occurredAt: date(100))
        let kept = makeTransaction(id: uuid(5), note: "Keep", amount: 20, occurredAt: date(200))
        try repository.saveTransaction(deleted)
        try repository.saveTransaction(kept)

        try repository.deleteTransaction(id: deleted.id)

        XCTAssertEqual(try repository.fetchTransactions(), [kept])
    }

    func test_deleteTransactions_removesMatchingRecords() throws {
        let repository = try makeRepository()
        let first = makeTransaction(id: uuid(6), note: "First", amount: 10, occurredAt: date(100))
        let second = makeTransaction(id: uuid(7), note: "Second", amount: 20, occurredAt: date(200))
        let kept = makeTransaction(id: uuid(8), note: "Keep", amount: 30, occurredAt: date(300))
        try repository.saveTransaction(first)
        try repository.saveTransaction(second)
        try repository.saveTransaction(kept)

        try repository.deleteTransactions(ids: [first.id, second.id])

        XCTAssertEqual(try repository.fetchTransactions(), [kept])
    }

    func test_saveBalanceMonth_roundTripsAndNormalizesMonthStart() throws {
        let repository = try makeRepository()
        let inputDate = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(secondsFromGMT: 0),
            year: 2026,
            month: 9,
            day: 28,
            hour: 15
        ).date!
        let expectedMonthStart = Calendar.current.date(
            from: Calendar.current.dateComponents([.year, .month], from: inputDate)
        )!

        try repository.saveBalanceMonth(BalanceMonth(monthStart: inputDate, isLocked: true))

        XCTAssertEqual(try repository.fetchBalanceMonths(), [
            BalanceMonth(monthStart: expectedMonthStart, isLocked: true)
        ])
        XCTAssertEqual(
            try repository.fetchBalanceMonth(monthStart: expectedMonthStart),
            BalanceMonth(monthStart: expectedMonthStart, isLocked: true)
        )
    }

    private func makeRepository() throws -> ImpBalanceRepository {
        let container = try FinanceRepositoryTestSupport.makeBalanceContainer()
        return ImpBalanceRepository(modelContext: ModelContext(container))
    }

    private func makeTransaction(id: UUID, note: String, amount: Decimal, occurredAt: Date) -> Transaction {
        Transaction(
            id: id,
            note: note,
            type: .expense,
            category: .food,
            method: .cash,
            amount: amount,
            occurredAt: occurredAt,
            createAt: date(0)
        )
    }

    private func uuid(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", value))!
    }

    private func date(_ value: TimeInterval) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
