//
//  HomeRouter.swift
//  CineTrack
//
//  Created by TiniT on 15/4/26.
//

import SwiftUI
import Observation

enum HomeRoute: Hashable {
    case habitDetail(UUID)
    case createHabit
}

@Observable
final class HomeRouter: AppRouter<HomeRoute> {
    func popToView(_ target: HomeRoute) {
        if let index = path.lastIndex(of: target) {
            path = Array(path.prefix(index + 1))
        }
    }
}
