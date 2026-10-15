//
//  BudgetUseCase.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

public protocol BudgetUseCase {}

public final class ImpBudgetUseCase: BudgetUseCase {
    private let repository: any BudgetRepository
    
    public init(repository: any BudgetRepository) {
        self.repository = repository
    }
}
