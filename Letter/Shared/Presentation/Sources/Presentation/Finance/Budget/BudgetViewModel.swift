//
//  BudgetViewModel.swift
//  Presentation
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Domain

import Observation

@Observable
public final class BudgetViewModel {
    private let useCase: any BudgetUseCase
    
    
    public init(useCase: any BudgetUseCase) {
        self.useCase = useCase
    }
}
