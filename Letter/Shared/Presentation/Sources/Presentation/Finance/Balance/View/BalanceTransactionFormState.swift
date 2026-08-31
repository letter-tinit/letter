import Foundation
import Domain
import Utility

enum BalanceTransactionFormValidationError: Error, Equatable {
    case amountRequired
    case invalidAmount
    case amountMustBePositive

    var localizationKey: String {
        switch self {
        case .amountRequired: "transaction.form.error.amount.required"
        case .invalidAmount: "transaction.form.error.amount.invalid"
        case .amountMustBePositive: "transaction.form.error.amount.positive"
        }
    }
}

struct BalanceTransactionFormState: Equatable {
    var description: String
    var transactionType: TransactionType
    var category: TransactionCategory
    var occurredAt: Date
    var amountText: String
    var paymentMethod: PaymentMethod

    static var template: Self {
        Self(
            description: "",
            transactionType: .income,
            category: .other,
            occurredAt: .now,
            amountText: "",
            paymentMethod: .banking
        )
    }

    init(transaction: Transaction) {
        description = transaction.note ?? ""
        transactionType = transaction.type
        category = transaction.category
        occurredAt = transaction.occurredAt
        amountText = transaction.amount.toAmountString
        paymentMethod = transaction.method
    }

    private init(
        description: String,
        transactionType: TransactionType,
        category: TransactionCategory,
        occurredAt: Date,
        amountText: String,
        paymentMethod: PaymentMethod
    ) {
        self.description = description
        self.transactionType = transactionType
        self.category = category
        self.occurredAt = occurredAt
        self.amountText = amountText
        self.paymentMethod = paymentMethod
    }

    func validatedTransaction(updating original: Transaction?) throws -> Transaction {
        let normalizedAmount = amountText
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedAmount.isEmpty else {
            throw BalanceTransactionFormValidationError.amountRequired
        }
        guard let amount = Decimal(string: normalizedAmount) else {
            throw BalanceTransactionFormValidationError.invalidAmount
        }
        guard amount > 0 else {
            throw BalanceTransactionFormValidationError.amountMustBePositive
        }

        return Transaction(
            id: original?.id ?? UUID(),
            note: description.trimmingCharacters(in: .whitespacesAndNewlines),
            type: transactionType,
            category: category,
            method: paymentMethod,
            amount: amount,
            occurredAt: occurredAt,
            createAt: original?.createAt ?? .now
        )
    }
}
