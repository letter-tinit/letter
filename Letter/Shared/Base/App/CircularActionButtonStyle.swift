//
//  CircularActionButtonStyle.swift
//  Letter
//
//  Created by Tín Nguyễn on 26/8/26.
//

import SwiftUI

struct CircularActionButtonStyle: View {
    private let imageName: String
    private let title: String?
    private let color: Color
    private let action: () -> Void
    
    init(
        imageName: String,
        title: String? = nil,
        color: Color = .primary,
        action: @escaping () -> Void
    ) {
        self.imageName = imageName
        self.title = title
        self.color = color
        self.action = action
    }
    
    var body: some View {
        Button {
            Haptic.selection()
            action()
        } label: {
            VStack {
                Image(systemName: imageName)
                    .circularImageStyle(with: color)
                if let title {
                    Text(title)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
