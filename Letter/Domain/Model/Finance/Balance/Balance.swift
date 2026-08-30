//
//  Balance.swift
//  Letter
//
//  Created by TiniT on 16/7/26.
//

import Foundation

struct Balance {
    var transactions: [Transaction]
    
    init(transactions: [Transaction] = []) {
        self.transactions = transactions
    }
}

struct BalanceData {
    let transactions: [Transaction]
    let months: [BalanceMonth]
}

enum BalanceStatus: Codable {
    case positive
    case negative
    case balanced
}

extension Balance {
    var inflow: Decimal {
        transactions
            .filter{ $0.type == .income }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }
    
    var outflow: Decimal {
        transactions
            .filter{ $0.type == .expense }
            .reduce(Decimal.zero) { partialResult, transaction in
                partialResult + transaction.amount
            }
    }
    
    var status: BalanceStatus {
        if inflow > outflow {
            return .positive
        } else if inflow < outflow {
            return .negative
        } else {
            return .balanced
        }
    }
    
    
    var symbol: String {
        switch status {
        case .positive:
            return "arrow.up.circle.fill"
            
        case .negative:
            return "arrow.down.circle.fill"
            
        case .balanced:
            return "equal.circle.fill"
        }
    }
    
    var name: String {
        switch status {
        case .positive:
            return "balance.status.positive"
            
        case .negative:
            return "balance.status.negative"
            
        case .balanced:
            return "balance.status.balanced"
        }
    }
    
    var sign: String {
        switch status {
        case .positive:
            "+"
        case .negative:
            "-"
        case .balanced:
            ""
        }
    }
    
    var displayBalance: String {
        sign + balance.formattedVND
    }
    
    var balance: Decimal {
        abs((inflow - outflow))
    }
    
    var transactionRows: [TransactionRowModel] {
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

struct TransactionRowModel: Identifiable, Hashable {
    let id: UUID
    let transaction: Transaction
    let balanceSnapshot: Decimal
}
