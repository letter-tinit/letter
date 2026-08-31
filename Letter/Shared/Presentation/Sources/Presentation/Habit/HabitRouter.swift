//
//  HabitRouter.swift
//  CineTrack
//
//  Created by TiniT on 15/4/26.
//

import SwiftUI
import Observation
import Domain
import Utility
import Styleguide

public enum HabitRoute: Hashable {
    case habitDetail(UUID)
    case createHabit
}

@Observable
public final class HabitRouter: AppRouter<HabitRoute> {
    public func popToView(_ target: HabitRoute) {
        if let index = path.lastIndex(of: target) {
            path = Array(path.prefix(index + 1))
        }
    }
}
