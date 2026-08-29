//
//  HabitRouter.swift
//  CineTrack
//
//  Created by TiniT on 15/4/26.
//

import SwiftUI
import Observation

enum HabitRoute: Hashable {
    case habitDetail(UUID)
    case createHabit
}

@Observable
final class HabitRouter: AppRouter<HabitRoute> {
    func popToView(_ target: HabitRoute) {
        if let index = path.lastIndex(of: target) {
            path = Array(path.prefix(index + 1))
        }
    }
}
