//
//  AppNavigationStack.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI
import Domain
import Utility

public struct AppNavigationStack<Route: Hashable, Content: View, Destination: View>: View {
    @Binding var path: [Route]
    @ViewBuilder
    let content: () -> Content
    @ViewBuilder
    let destination: (Route) -> Destination
    public init(path: Binding<[Route]>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder destination: @escaping (Route) -> Destination) { self._path = path; self.content = content; self.destination = destination }
    
    public var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: Route.self) { route in
                    destination(route)
                }
        }
    }
}
