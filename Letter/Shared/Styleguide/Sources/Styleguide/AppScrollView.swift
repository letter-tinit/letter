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
    private let scrollBounceBehavior: ScrollBounceBehavior
    
    let content: () -> Content
    
    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = false,
        scrollBounceBehavior: ScrollBounceBehavior = .basedOnSize,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.content = content
        self.scrollBounceBehavior = scrollBounceBehavior
    }
    
    public var body: some View {
        ScrollView(axes, showsIndicators: showsIndicators) {
            content()
        }
        .scrollBounceBehavior(scrollBounceBehavior, axes: axes)
        .scrollIndicators(showsIndicators ? .visible : .hidden)
    }
}
