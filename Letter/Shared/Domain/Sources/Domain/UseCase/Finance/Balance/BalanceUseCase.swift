import Foundation
import Utility

public protocol BalanceUseCase {
    func load() throws -> BalanceData
    func saveTransaction(_ input: TransactionInput, updating transaction: Transaction?) throws
    func deleteTransaction(_ transaction: Transaction) throws
    func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) throws
    func deleteTransactions(_ transactions: [Transaction]) throws
}

public final class ImpBalanceUseCase: BalanceUseCase {
    private let repository: any BalanceRepository

    public init(repository: any BalanceRepository) {
        self.repository = repository
    }

    public func load() throws -> BalanceData {
        BalanceData(
            transactions: try repository.fetchTransactions(),
            months: try repository.fetchBalanceMonths()
        )
    }

    public func saveTransaction(
        _ input: TransactionInput,
        updating transaction: Transaction?
    ) throws {
        let amount = try validatedAmount(input.amountText)

        if let transaction {
            apply(input, amount: amount, to: transaction)
            try repository.saveTransaction(transaction)
        } else {
            let transaction = Transaction(
                note: input.description.trimmingCharacters(in: .whitespacesAndNewlines),
                type: input.transactionType,
                category: input.category,
                method: input.paymentMethod,
                amount: amount,
                occurredAt: input.occurredAt
            )
            try repository.saveTransaction(transaction)
        }
    }

    public func deleteTransaction(_ transaction: Transaction) throws {
        try repository.deleteTransaction(id: transaction.id)
    }

    public func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) throws {
        if let month {
            month.isLocked.toggle()
            try repository.saveBalanceMonth(month)
        } else {
            let month = BalanceMonth(monthStart: monthStart)
            month.isLocked = true
            try repository.saveBalanceMonth(month)
        }
    }

    public func deleteTransactions(_ transactions: [Transaction]) throws {
        try repository.deleteTransactions(ids: Set(transactions.map(\.id)))
    }
}

private extension ImpBalanceUseCase {
    public func validatedAmount(_ text: String) throws -> Decimal {
        let normalized = text
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { throw TransactionFormValidationError.amountRequired }
        guard let amount = Decimal(string: normalized) else {
            throw TransactionFormValidationError.invalidAmount
        }
        guard amount > 0 else { throw TransactionFormValidationError.amountMustBePositive }
        return amount
    }

    public func apply(_ input: TransactionInput, amount: Decimal, to transaction: Transaction) {
        transaction.note = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.type = input.transactionType
        transaction.category = input.category
        transaction.method = input.paymentMethod
        transaction.amount = amount
        transaction.occurredAt = input.occurredAt
    }
}
