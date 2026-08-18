//
//  AppScrollView.swift
//  Habit
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

struct AppScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    
    let content: () -> Content
    
    init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        @ViewBuilder content: @escaping () -> Content) {
            self.axes = axes
            self.showsIndicators = showsIndicators
            self.content = content
        }
    
    var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .scrollBounceBehavior(.basedOnSize, axes: axes)
        .scrollIndicators(showsIndicators ? .visible : .hidden)
    }
}
