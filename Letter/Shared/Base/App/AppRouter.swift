//
//  AppRouter.swift
//  Letter
//
//  Created by TiniT on 14/4/26.
//

import SwiftUI
import Observation

@Observable
class AppRouter<Route: Hashable> {
    var path: [Route] = []
    
    func push(_ route: Route) {
        path.append(route)
    }
    
    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }
    
    func popToRoot() {
        path.removeAll()
    }
}
