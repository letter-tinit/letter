//
//  Balance.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import Foundation

public struct Balance {
    public var transactions: [Transaction]
    
    public init(transactions: [Transaction] = []) {
        self.transactions = transactions
    }
}

public enum BalanceStatus: Codable {
    case positive
    case negative
    case balanced
}

public extension Balance {
    public var inflow: Decimal {
        transactions
            .filter{ $0.type == .income }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }
    
    public var outflow: Decimal {
        transactions
            .filter{ $0.type == .expense }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }
    
    public var status: BalanceStatus {
        if inflow > outflow {
            return .positive
        } else if inflow < outflow {
            return .negative
        } else {
            return .balanced
        }
    }
    
    
    public var balance: Decimal {
        abs((inflow - outflow))
    }
}
