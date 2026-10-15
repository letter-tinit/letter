//
//  BudgetUseCase.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public protocol BudgetUseCase {
    func load(_ date: Date) throws -> Budget?
}

public final class ImpBudgetUseCase: BudgetUseCase {
    private let repository: any BudgetRepository
    
    public init(repository: any BudgetRepository) {
        self.repository = repository
    }
    
    public func load(_ date: Date) throws -> Budget? {
        try repository.load(date)
    }
}
