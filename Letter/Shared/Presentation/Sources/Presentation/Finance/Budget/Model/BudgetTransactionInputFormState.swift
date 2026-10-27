//
//  BudgetTransactionInputFormState.swift
//  Presentation
//
//  Created by Tín Nguyễn on 22/10/26.
//

import Foundation
import Observation
import Domain

@Observable
public final class BudgetTransactionInputFormState {
    // MARK: - Input
    public var amount = ""
    public var description = BudgetTransactionCategory.other.defaultDescription
    public var date = Date()
    public var category: BudgetTransactionCategory = .other
    
    // MARK: - Validation
    
    // MARK: - RESET
    public func reset() {
        amount = ""
        description = BudgetTransactionCategory.other.defaultDescription
        date = Date()
        category = .other
    }
}

extension BudgetTransactionInputFormState {
    func mapFromPresentationModel(transaction: BudgetTransactionPresentationModel) {
        self.amount = transaction.amount.toAmountString
        self.description = transaction.description
        self.date = transaction.date
        self.category = transaction.category
    }
}
