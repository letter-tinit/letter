//
//  BudgetMethod.swift
//  Personal Finance
//
//  Created by TiniT on 9/7/26.
//

import Foundation

enum BudgetMethod: String, CaseIterable, Hashable, Codable {
    case fiftyThirtyTwenty
    case sixJars
    
    var localizationKey: String {
        switch self {
        case .fiftyThirtyTwenty:
            return "budget.method.fiftyThirtyTwenty"
        case .sixJars:
            return "budget.method.sixJars"
        }
    }
    
    func generateBucketByIncome(_ income: Decimal) -> [BudgetBucket] {
        switch self {
        case .fiftyThirtyTwenty:
            return [
                BudgetBucket(kind: .needs, ratio: 0.5, amount: income * 0.5),
                BudgetBucket(kind: .wants, ratio: 0.3, amount: income * 0.3),
                BudgetBucket(kind: .savings, ratio: 0.2, amount: income * 0.2),
            ]
        case .sixJars:
            return [
                BudgetBucket(kind: .necessities, ratio: 0.55, amount: income * 0.55),
                BudgetBucket(kind: .financialFreedom, ratio: 0.10, amount: income * 0.10),
                BudgetBucket(kind: .education, ratio: 0.10, amount: income * 0.10),
                BudgetBucket(kind: .longTermSavings, ratio: 0.10, amount: income * 0.10),
                BudgetBucket(kind: .play, ratio: 0.10, amount: income * 0.10),
                BudgetBucket(kind: .give, ratio: 0.05, amount: income * 0.05),
            ]
        }
    }
}

struct BudgetBucket: Hashable {
    let kind: BudgetBucketKind
    let ratio: Decimal
    let amount: Decimal
}

nonisolated
enum BudgetBucketKind: Hashable, Codable {
    case needs
    case wants
    case savings
    case necessities
    case financialFreedom
    case education
    case longTermSavings
    case play
    case give
    case custom(id: String)
    
    var id: String {
        switch self {
        case .needs:
            return "needs"
        case .wants:
            return "wants"
        case .savings:
            return "savings"
        case .necessities:
            return "necessities"
        case .financialFreedom:
            return "financialFreedom"
        case .education:
            return "education"
        case .longTermSavings:
            return "longTermSavings"
        case .play:
            return "play"
        case .give:
            return "give"
        case .custom(let id):
            return id
        }
    }
    
    var localizationKey: String {
        "bucket.\(id)"
    }

    var isSavingsLike: Bool {
        switch self {
        case .savings, .financialFreedom, .longTermSavings:
            true
        default:
            false
        }
    }

    var supportsFixedExpensePlan: Bool {
        switch self {
        case .needs, .necessities:
            true
        default:
            false
        }
    }
}
