//
//  BudgetTransactionGroup.swift
//  Personal Finance
//
//  Created by TiniT on 24/7/26.
//

import Foundation

struct TransactionGroup: Identifiable {
    let date: Date
    let transactions: [BudgetTransaction]
    var id: Date { date }
}
