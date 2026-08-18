//
//  AppNavigationStack.swift
//  Habit
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct AppNavigationStack<Route: Hashable, Content: View, Destination: View>: View {
    @Binding var path: [Route]
    @ViewBuilder
    let content: () -> Content
    @ViewBuilder
    let destination: (Route) -> Destination
    
    var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
    }
}
