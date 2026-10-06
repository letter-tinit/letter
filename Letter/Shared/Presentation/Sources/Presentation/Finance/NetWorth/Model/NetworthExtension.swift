//
//  NetworthExtension.swift
//  Presentation
//
//  Created by Tín Nguyễn on 6/10/26.
//

import SwiftUI
import Domain

extension NetWorthCategoryType {
    public var localizationKey: String {
        switch self {
        case .cashAndCashEquivalents:
            "networth.category.cashEquivalents"
        case .receivables:
            "networth.category.receivables"
        case .tangibleAssets:
            "networth.category.tangibleAssets"
        case .financialAssets:
            "networth.category.financialAssets"
        case .shortTermDebt:
            "networth.category.shortTermDebt"
        case .longTermDebt:
            "networth.category.longTermDebt"
        }
    }
}

extension NetWorthGroupType {
    public var localizationKey: String {
        switch self {
        case .assets:
            "networth.group.assets"
        case .liabilities:
            "networth.group.liabilities"
        }
    }

    public var systemImage: String {
        switch self {
        case .assets:
            "building.columns"
        case .liabilities:
            "creditcard"
        }
    }

    public var totalLocalizationKey: String {
        switch self {
        case .assets:
            "networth.total.assets"
        case .liabilities:
            "networth.total.liabilities"
        }
    }

    public var tint: Color {
        switch self {
        case .assets:
            .green
        case .liabilities:
            .orange
        }
    }
}
