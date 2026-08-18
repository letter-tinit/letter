//
//  StatisticalRouter.swift
//  Habit
//
//  Created by TiniT on 26/5/26.
//

import SwiftUI
import Observation

enum StatisticalRoute: Hashable {}

@Observable
final class StatisticalRouter: AppRouter<HomeRoute> {
    func popToView(_ target: HomeRoute) {
        if let index = path.lastIndex(of: target) {
            path = Array(path.prefix(index + 1))
        }
    }
}
