import Foundation

protocol BalanceUseCase {
    func saveTransaction(_ input: TransactionInput, updating transaction: Transaction?) throws
    func deleteTransaction(_ transaction: Transaction) throws
    func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) throws
    func deleteTransactions(_ transactions: [Transaction]) throws
}

final class ImpBalanceUseCase: BalanceUseCase {
    private let repository: any BalanceRepository

    init(repository: any BalanceRepository) {
        self.repository = repository
    }

    func saveTransaction(
        _ input: TransactionInput,
        updating transaction: Transaction?
    ) throws {
        let amount = try validatedAmount(input.amountText)

        if let transaction {
            apply(input, amount: amount, to: transaction)
            try repository.updateTransaction(transaction)
        } else {
            let transaction = Transaction(
                note: input.description.trimmingCharacters(in: .whitespacesAndNewlines),
                type: input.transactionType,
                category: input.category,
                method: input.paymentMethod,
                amount: amount,
                occurredAt: input.occurredAt
            )
            try repository.addTransaction(transaction)
        }
    }

    func deleteTransaction(_ transaction: Transaction) throws {
        try repository.deleteTransaction(transaction)
    }

    func toggleEditingLock(for month: BalanceMonth?, monthStart: Date) throws {
        if let month {
            month.isLocked.toggle()
            try repository.save()
        } else {
            let month = BalanceMonth(monthStart: monthStart)
            month.isLocked = true
            try repository.addBalanceMonth(month)
        }
    }

    func deleteTransactions(_ transactions: [Transaction]) throws {
        try repository.deleteTransactions(transactions)
    }
}

private extension ImpBalanceUseCase {
    func validatedAmount(_ text: String) throws -> Decimal {
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

    func apply(_ input: TransactionInput, amount: Decimal, to transaction: Transaction) {
        transaction.note = input.description.trimmingCharacters(in: .whitespacesAndNewlines)
        transaction.type = input.transactionType
        transaction.category = input.category
        transaction.method = input.paymentMethod
        transaction.amount = amount
        transaction.occurredAt = input.occurredAt
    }
}
