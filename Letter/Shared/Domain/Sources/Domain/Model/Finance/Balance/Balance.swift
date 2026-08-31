//
//  Balance.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import Foundation
import Utility

public struct Balance {
    public var transactions: [Transaction]
    
    public init(transactions: [Transaction] = []) {
        self.transactions = transactions
    }
}

public struct BalanceData {
    public let transactions: [Transaction]
    public let months: [BalanceMonth]
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
    
    
    public var symbol: String {
        switch status {
        case .positive:
            return "arrow.up.circle.fill"
            
        case .negative:
            return "arrow.down.circle.fill"
            
        case .balanced:
            return "equal.circle.fill"
        }
    }
    
    public var name: String {
        switch status {
        case .positive:
            return "balance.status.positive"
            
        case .negative:
            return "balance.status.negative"
            
        case .balanced:
            return "balance.status.balanced"
        }
    }
    
    public var sign: String {
        switch status {
        case .positive:
            "+"
        case .negative:
            "-"
        case .balanced:
            ""
        }
    }
    
    public var displayBalance: String {
        sign + balance.formattedVND
    }
    
    public var balance: Decimal {
        abs((inflow - outflow))
    }
    
    public var transactionRows: [TransactionRowModel] {
        var balance: Decimal = 0
        
        let rows = transactions
            .sorted {
                $0.occurredAt < $1.occurredAt
            }
            .map { transaction in
                
                balance += transaction.type == .income
                ? transaction.amount
                : -transaction.amount
                
                return TransactionRowModel(
                    id: transaction.id,
                    transaction: transaction,
                    balanceSnapshot: balance
                )
            }
        
        return Array(rows.reversed())
    }
}

public struct TransactionRowModel: Identifiable, Hashable {
    public let id: UUID
    public let transaction: Transaction
    public let balanceSnapshot: Decimal
}
