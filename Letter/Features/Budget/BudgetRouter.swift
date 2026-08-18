//
//  BudgetRouter.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI
import Observation

enum BudgetRoute: Hashable {
    case budget(Budget)
}

@Observable
final class BudgetRouter: AppRouter<BudgetRoute> {
    func popToView(_ target: BudgetRoute) {
        if let index = path.lastIndex(of: target) {
            path = Array(path.prefix(index + 1))
        }
    }
}
