import Foundation
import Observation
import SwiftUI
import Domain
import Utility
import Styleguide

public enum BalancePresentationStatus {
    case positive
    case negative
    case balanced
}

@Observable
public final class BalanceTransactionPresentationModel: Identifiable {
    public let id: UUID
    public var note: String?
    public var type: TransactionType
    public var category: TransactionCategory
    public var method: PaymentMethod
    public var amount: Decimal
    public var occurredAt: Date
    public var createAt: Date

    public init(transaction: Domain.Transaction) {
        id = transaction.id
        note = transaction.note
        type = transaction.type
        category = transaction.category
        method = transaction.method
        amount = transaction.amount
        occurredAt = transaction.occurredAt
        createAt = transaction.createAt
    }

    public var domainTransaction: Domain.Transaction {
        Domain.Transaction(
            id: id,
            note: note,
            type: type,
            category: category,
            method: method,
            amount: amount,
            occurredAt: occurredAt,
            createAt: createAt
        )
    }
}

public struct BalanceTransactionRowModel: Identifiable {
    public let id: UUID
    public let transaction: BalanceTransactionPresentationModel
    public let balanceSnapshot: Decimal
}

@Observable
public final class BalancePresentationModel {
    public var transactions: [BalanceTransactionPresentationModel]
    public var summaryTransactions: [BalanceTransactionPresentationModel]
    public var isEditingUnlocked: Bool

    public init(
        transactions: [BalanceTransactionPresentationModel] = [],
        summaryTransactions: [BalanceTransactionPresentationModel] = [],
        isEditingUnlocked: Bool = true
    ) {
        self.transactions = transactions
        self.summaryTransactions = summaryTransactions
        self.isEditingUnlocked = isEditingUnlocked
    }

    public var inflow: Decimal {
        summaryTransactions
            .filter { $0.type == .income }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }

    public var outflow: Decimal {
        summaryTransactions
            .filter { $0.type == .expense }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }

    public var status: BalancePresentationStatus {
        if inflow > outflow {
            return .positive
        } else if inflow < outflow {
            return .negative
        } else {
            return .balanced
        }
    }

    public var netAmount: Decimal {
        abs(inflow - outflow)
    }

    var symbol: String {
        switch status {
        case .positive: "arrow.up.circle.fill"
        case .negative: "arrow.down.circle.fill"
        case .balanced: "equal.circle.fill"
        }
    }

    var name: String {
        switch status {
        case .positive: "balance.status.positive"
        case .negative: "balance.status.negative"
        case .balanced: "balance.status.balanced"
        }
    }

    var displayBalance: String {
        let sign = switch status {
        case .positive: "+"
        case .negative: "-"
        case .balanced: ""
        }
        return sign + netAmount.formattedVND
    }

    var color: Color {
        switch status {
        case .positive:
            return Color.Common.success
        case .negative:
            return Color.Common.failure
        case .balanced:
            return Color.Common.surface
        }
    }

    var transactionRows: [BalanceTransactionRowModel] {
        var runningBalance: Decimal = 0
        let rows = transactions
            .sorted { $0.occurredAt < $1.occurredAt }
            .map { transaction in
                runningBalance += transaction.type == .income
                    ? transaction.amount
                    : -transaction.amount
                return BalanceTransactionRowModel(
                    id: transaction.id,
                    transaction: transaction,
                    balanceSnapshot: runningBalance
                )
            }
        return Array(rows.reversed())
    }
}

public extension TransactionType {
    var localizedTitle: String {
        "transaction.type.\(rawValue)".localized
    }
}

public extension TransactionCategory {
    var localizedTitle: String {
        "transaction.category.\(rawValue)".localized
    }

    var icon: String {
        switch self {
        case .food: "fork.knife"
        case .transport: "car"
        case .housing: "house"
        case .shopping: "bag"
        case .entertainment: "gamecontroller"
        case .health: "heart"
        case .education: "book"
        case .salary: "banknote"
        case .investment: "chart.line.uptrend.xyaxis"
        case .carryover: "checkmark.seal.text.page"
        case .other: "ellipsis.circle"
        }
    }
}
