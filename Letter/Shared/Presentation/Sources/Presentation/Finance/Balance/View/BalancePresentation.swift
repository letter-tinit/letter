import Foundation
import Domain
import Utility

public struct TransactionRowModel: Identifiable, Hashable {
    public let id: UUID
    public let transaction: Domain.Transaction
    public let balanceSnapshot: Decimal
}

public extension Balance {
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
        return sign + balance.formattedVND
    }

    var transactionRows: [TransactionRowModel] {
        var runningBalance: Decimal = 0
        let rows = transactions
            .sorted { $0.occurredAt < $1.occurredAt }
            .map { transaction in
                runningBalance += transaction.type == .income
                    ? transaction.amount
                    : -transaction.amount
                return TransactionRowModel(
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
