//
//  HabitProfileRouter.swift
//  Habit
//
//  Created by TiniT on 25/5/26.
//

import Observation

enum HabitProfileRoute: Hashable {
    case editProfile
}

@Observable
final class HabitProfileRouter: AppRouter<HabitProfileRoute> {}
