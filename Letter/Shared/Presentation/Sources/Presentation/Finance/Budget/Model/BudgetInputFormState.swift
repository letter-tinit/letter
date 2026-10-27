//
//  BudgetInputFormState.swift
//  Presentation
//
//  Created by Tín Nguyễn on 16/10/26.
//


import Foundation
import Observation

@Observable
public final class BudgetInputFormState {
    // MARK: - Input
    
    public var incomeAmount = ""
    public var pyfAmount = ""
    
    // MARK: - Validation
    
    private(set) public var hasSubmitted = false
    
    private var incomeValidationError: String? {
        guard !incomeAmount.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty else {
            return "budget.creation.validation.income_required".localized
        }
        
        guard incomeAmountValue > .zero else {
            return "budget.creation.validation.income_invalid".localized
        }
        
        return nil
    }
    
    private var pyfValidationError: String? {
        guard pyfAmountValue >= .zero else {
            return "budget.creation.validation.pyf_invalid".localized
        }
        
        guard pyfAmountValue <= incomeAmountValue else {
            return "budget.creation.validation.pyf_exceeds_income".localized
        }
        
        return nil
    }
    
    public var incomeAmountError: String? {
        guard hasSubmitted else { return nil }
        return incomeValidationError
    }
    
    public var pyfAmountError: String? {
        guard hasSubmitted else { return nil }
        return pyfValidationError
    }
    
    public var isValid: Bool {
        incomeValidationError == nil &&
        pyfValidationError == nil
    }
    
    // MARK: - Derived Values
    
    public var incomeAmountValue: Decimal {
        incomeAmount.toDecimal()
    }
    
    public var pyfAmountValue: Decimal {
        pyfAmount.toDecimal()
    }
    
    public var spendingAmount: Decimal {
        incomeAmountValue - pyfAmountValue
    }
    
    public var spendingAmountString: String {
        spendingAmount.formattedVND
    }
    
    // MARK: - Actions
    
    func validate() throws {
        hasSubmitted = true
        
        if incomeAmount.trimmingCharacters(
            in: .whitespacesAndNewlines
        ).isEmpty {
            throw BudgetCreationError.incomeRequired
        }
        
        if incomeAmountValue <= .zero {
            throw BudgetCreationError.incomeInvalid
        }
        
        if pyfAmountValue < .zero {
            throw BudgetCreationError.pyfInvalid
        }
        
        if pyfAmountValue > incomeAmountValue {
            throw BudgetCreationError.pyfExceedsIncome
        }
    }
    
    public func reset() {
        incomeAmount = ""
        pyfAmount = ""
        hasSubmitted = false
    }
}

enum BudgetCreationError: LocalizedError {
    case incomeRequired
    case incomeInvalid
    case pyfInvalid
    case pyfExceedsIncome
    
    var errorDescription: String? {
        switch self {
        case .incomeRequired:
            "budget.creation.validation.income_required".localized
        case .incomeInvalid:
            "budget.creation.validation.income_invalid".localized
        case .pyfInvalid:
            "budget.creation.validation.pyf_invalid".localized
        case .pyfExceedsIncome:
            "budget.creation.validation.pyf_exceeds_income".localized
        }
    }
}
