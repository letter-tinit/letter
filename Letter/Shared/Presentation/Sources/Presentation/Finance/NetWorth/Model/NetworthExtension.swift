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
        case .cashAndBank:
            "networth.category.cashAndBank"
        case .receivables:
            "networth.category.receivables"
        case .personalProperty:
            "networth.category.personalProperty"
        case .investment:
            "networth.category.investment"
        case .credit:
            "networth.category.credit"
        case .shortTermDebt:
            "networth.category.shortTermDebt"
        case .longTermDebt:
            "networth.category.longTermDebt"
        }
    }
}
