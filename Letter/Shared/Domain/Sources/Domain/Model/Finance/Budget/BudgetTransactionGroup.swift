//
//  BudgetTransactionGroup.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

import Foundation
import Utility

public struct TransactionGroup: Identifiable {
    public let date: Date
    public let transactions: [BudgetTransaction]
    public var id: Date { date }
}
