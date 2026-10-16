//
//  AppList.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 16/9/26.
//

import SwiftUI

public struct AppList<Content: View>: View {
    private let scrollBounceBehavior: ScrollBounceBehavior
    private let lastItemSpacing: CGFloat = 0.0
    private let content: Content

    public init(
        scrollBounceBehavior: ScrollBounceBehavior = .basedOnSize,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.scrollBounceBehavior = scrollBounceBehavior
    }

    public var body: some View {
        List {
            content
                .listRowInsets(EdgeInsets())
                .clearDefaultConfigure()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(scrollBounceBehavior)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: lastItemSpacing)
        }
    }
}
