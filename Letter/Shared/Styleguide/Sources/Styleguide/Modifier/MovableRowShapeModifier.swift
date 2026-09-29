//
//  MovableRowShapeModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 29/9/26.
//

import SwiftUI

public struct MovableRowShapeModifier<RowShape: Shape>: ViewModifier {
    let shape: RowShape

    public func body(content: Content) -> some View {
        content
            .contentShape(shape)
            .contentShape(.dragPreview, shape)
            .clipShape(shape)
    }
}

public extension View {
    func movableRowShape<RowShape: Shape>(_ shape: RowShape) -> some View {
        modifier(MovableRowShapeModifier(shape: shape))
    }
}
