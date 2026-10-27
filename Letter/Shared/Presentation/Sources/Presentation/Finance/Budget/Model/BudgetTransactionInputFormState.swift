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
    private(set) public var hasSubmitted = false

    private var amountValidationError: BudgetTransactionInputValidationError? {
        guard !amount.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .amountRequired
        }
        guard amount.toDecimal() > .zero else { return .amountInvalid }
        return nil
    }

    public var amountError: String? {
        guard hasSubmitted, let error = amountValidationError else { return nil }
        return error.localizedDescription
    }

    public var isValid: Bool {
        amountValidationError == nil
    }

    func validate() throws {
        hasSubmitted = true
        if let error = amountValidationError { throw error }
    }
    
    // MARK: - RESET
    public func reset() {
        amount = ""
        description = BudgetTransactionCategory.other.defaultDescription
        date = Date()
        category = .other
        hasSubmitted = false
    }
}

private enum BudgetTransactionInputValidationError: LocalizedError {
    case amountRequired
    case amountInvalid

    var errorDescription: String? {
        switch self {
        case .amountRequired: "transaction.form.error.amount.required".localized
        case .amountInvalid: "transaction.form.error.amount.invalid".localized
        }
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
