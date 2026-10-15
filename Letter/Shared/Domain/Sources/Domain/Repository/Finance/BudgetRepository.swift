//
//  BudgetRepository.swift
//  Domain
//
//  Created by Tín Nguyễn on 15/10/26.
//

import Foundation

public protocol BudgetRepository {
    func load(_ date: Date) throws -> Budget?
}
