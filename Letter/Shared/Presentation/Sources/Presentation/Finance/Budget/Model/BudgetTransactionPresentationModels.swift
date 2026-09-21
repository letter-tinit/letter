//
//  BudgetTransactionPresentationModels.swift
//  Letter
//
//  Created by Codex on 21/9/26.
//

import Foundation
import Observation
import Domain

@Observable
final class BudgetTransactionRowModel: Identifiable {
    let id: UUID
    var title: String
    var note: String
    var occurredAt: Date
    var amount: Decimal
    var paymentMethod: PaymentMethod
    var allocationID: UUID?
    var allocationKind: BudgetBucketKind?

    init(transaction: BudgetTransaction) {
        id = transaction.id
        title = transaction.title
        note = transaction.note
        occurredAt = transaction.occurredAt
        amount = transaction.amount
        paymentMethod = transaction.paymentMethod
        allocationID = transaction.allocation?.id
        allocationKind = transaction.allocation?.kind
    }
}

@Observable
final class BudgetTransactionGroupModel: Identifiable {
    let date: Date
    var transactions: [BudgetTransactionRowModel]
    var isExpanded: Bool

    var id: Date { date }

    var totalAmount: Decimal {
        transactions.reduce(.zero) { $0 + $1.amount }
    }

    init(
        date: Date,
        transactions: [BudgetTransactionRowModel],
        isExpanded: Bool = true
    ) {
        self.date = date
        self.transactions = transactions
        self.isExpanded = isExpanded
    }
}

struct BudgetTransactionGroupSnapshot: Equatable {
    let id: UUID
    let title: String
    let note: String
    let occurredAt: Date
    let amount: Decimal
    let paymentMethod: PaymentMethod
    let allocationID: UUID?
}

extension Array where Element == BudgetTransaction {
    var budgetTransactionGroupSnapshot: [BudgetTransactionGroupSnapshot] {
        map {
            BudgetTransactionGroupSnapshot(
                id: $0.id,
                title: $0.title,
                note: $0.note,
                occurredAt: $0.occurredAt,
                amount: $0.amount,
                paymentMethod: $0.paymentMethod,
                allocationID: $0.allocation?.id
            )
        }
    }
}
