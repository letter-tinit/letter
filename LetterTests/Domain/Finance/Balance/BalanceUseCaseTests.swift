import Foundation
import XCTest
@testable import Domain

@MainActor
final class BalanceUseCaseTests: XCTestCase {
    func test_load_returnsRepositoryData() throws {
        let transaction = makeTransaction(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!)
        let month = BalanceMonth(monthStart: Date(timeIntervalSince1970: 0), isLocked: true)
        let repository = FakeBalanceRepository(
            transactions: [transaction],
            months: [month]
        )
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.load()

        XCTAssertEqual(data.transactions, [transaction])
        XCTAssertEqual(data.months, [month])
    }

    func test_saveTransaction_persistsTransactionAndReturnsReloadedData() throws {
        let transaction = makeTransaction(id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!)
        let repository = FakeBalanceRepository()
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.saveTransaction(transaction)

        XCTAssertEqual(repository.savedTransactions, [transaction])
        XCTAssertEqual(data.transactions, [transaction])
    }

    func test_deleteTransaction_removesTransactionAndReturnsReloadedData() throws {
        let deletedID = UUID(uuidString: "00000000-0000-0000-0000-000000000003")!
        let keptTransaction = makeTransaction(id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!)
        let repository = FakeBalanceRepository(
            transactions: [
                makeTransaction(id: deletedID),
                keptTransaction
            ]
        )
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.deleteTransaction(id: deletedID)

        XCTAssertEqual(repository.deletedTransactionIDs, [deletedID])
        XCTAssertEqual(data.transactions, [keptTransaction])
    }

    func test_toggleEditingLock_usesExistingMonthWhenRepositoryHasOne() throws {
        let monthStart = Date(timeIntervalSince1970: 0)
        let repository = FakeBalanceRepository(
            months: [BalanceMonth(monthStart: monthStart, isLocked: false)]
        )
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.toggleEditingLock(for: BalanceMonth(monthStart: monthStart, isLocked: true))

        XCTAssertEqual(repository.savedMonths, [BalanceMonth(monthStart: monthStart, isLocked: true)])
        XCTAssertEqual(data.months, [BalanceMonth(monthStart: monthStart, isLocked: true)])
    }

    func test_toggleEditingLock_usesInputMonthWhenRepositoryDoesNotHaveOne() throws {
        let monthStart = Date(timeIntervalSince1970: 0)
        let repository = FakeBalanceRepository()
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.toggleEditingLock(for: BalanceMonth(monthStart: monthStart, isLocked: false))

        XCTAssertEqual(repository.savedMonths, [BalanceMonth(monthStart: monthStart, isLocked: true)])
        XCTAssertEqual(data.months, [BalanceMonth(monthStart: monthStart, isLocked: true)])
    }

    func test_deleteTransactions_removesMatchingTransactionsAndReturnsReloadedData() throws {
        let deletedIDs: Set<UUID> = [
            UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            UUID(uuidString: "00000000-0000-0000-0000-000000000006")!
        ]
        let keptTransaction = makeTransaction(id: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!)
        let repository = FakeBalanceRepository(
            transactions: deletedIDs.map(makeTransaction) + [keptTransaction]
        )
        let useCase = ImpBalanceUseCase(repository: repository)

        let data = try useCase.deleteTransactions(ids: deletedIDs)

        XCTAssertEqual(repository.deletedTransactionIDSets, [deletedIDs])
        XCTAssertEqual(data.transactions, [keptTransaction])
    }
}

private func makeTransaction(id: UUID) -> Transaction {
    Transaction(
        id: id,
        note: "Lunch",
        type: .expense,
        category: .food,
        method: .cash,
        amount: 12,
        occurredAt: Date(timeIntervalSince1970: 0),
        createAt: Date(timeIntervalSince1970: 0)
    )
}

@MainActor
private final class FakeBalanceRepository: BalanceRepository {
    var transactions: [Transaction]
    var months: [BalanceMonth]
    var savedTransactions: [Transaction] = []
    var deletedTransactionIDs: [UUID] = []
    var deletedTransactionIDSets: [Set<UUID>] = []
    var savedMonths: [BalanceMonth] = []

    init(transactions: [Transaction] = [], months: [BalanceMonth] = []) {
        self.transactions = transactions
        self.months = months
    }

    func fetchTransactions() throws -> [Transaction] {
        transactions
    }

    func fetchBalanceMonths() throws -> [BalanceMonth] {
        months
    }

    func fetchBalanceMonth(monthStart: Date) throws -> BalanceMonth? {
        months.first { $0.monthStart == monthStart }
    }

    func saveTransaction(_ transaction: Transaction) throws {
        savedTransactions.append(transaction)
        transactions.removeAll { $0.id == transaction.id }
        transactions.append(transaction)
    }

    func deleteTransaction(id: UUID) throws {
        deletedTransactionIDs.append(id)
        transactions.removeAll { $0.id == id }
    }

    func deleteTransactions(ids: Set<UUID>) throws {
        deletedTransactionIDSets.append(ids)
        transactions.removeAll { ids.contains($0.id) }
    }

    func saveBalanceMonth(_ month: BalanceMonth) throws {
        savedMonths.append(month)
        months.removeAll { $0.monthStart == month.monthStart }
        months.append(month)
    }
}
