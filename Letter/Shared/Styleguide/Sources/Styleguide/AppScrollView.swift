//
//  AppScrollView.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Domain
import Utility

public struct AppScrollView<Content: View>: View {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    
    let content: () -> Content
    
    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        @ViewBuilder content: @escaping () -> Content) {
            self.axes = axes
            self.showsIndicators = showsIndicators
            self.content = content
        }
    
    public var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .scrollBounceBehavior(.basedOnSize, axes: axes)
        .scrollIndicators(showsIndicators ? .visible : .hidden)
    }
}
