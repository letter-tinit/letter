//
//  AppListBottomSpacingModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 15/10/26.
//

import SwiftUI

public struct AppListBottomSpacingModifier: ViewModifier {
    private let spacing: CGFloat

    public init(spacing: CGFloat = 16) {
        self.spacing = spacing
    }

    public func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Color.clear
                    .frame(height: spacing)
            }
    }
}

public extension View {
    func appListBottomSpacing(_ spacing: CGFloat = 16) -> some View {
        modifier(
            AppListBottomSpacingModifier(spacing: spacing)
        )
    }
}
