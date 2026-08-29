//
//  BalanceRepository.swift
//  Letter
//
//  Created by TiniT on 20/7/26.
//

import Foundation

protocol BalanceRepository {
    func addTransaction(_ transaction: Transaction) throws
    
    func updateTransaction(_ transaction: Transaction) throws
    
    func deleteTransaction(_ transaction: Transaction) throws
    func deleteTransactions(_ transactions: [Transaction]) throws
    func addBalanceMonth(_ month: BalanceMonth) throws
    func save() throws
}
