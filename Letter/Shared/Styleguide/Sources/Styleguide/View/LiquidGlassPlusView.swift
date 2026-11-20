//
//  LiquidGlassPlusView.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 21/10/26.
//

import SwiftUI

public struct LiquidGlassPlusView: View {
    private let padding: CGFloat
    private let tint: Color
    
    public init(
        padding: CGFloat = 16,
        tint: Color = Color.Common.success
    ) {
        self.padding = padding
        self.tint = tint
    }
    
    public var body: some View {
        Image(systemName: "plus")
            .padding(padding)
            .appGlassEffect(
                .regular.interactive().tint(tint.opacity(0.15)),
                in: .circle
            )
            .foregroundStyle(tint)
    }
}
