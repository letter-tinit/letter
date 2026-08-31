//
//  CircularWithTitleProgressView.swift
//  Letter
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI
import Domain
import Core
import Utility
import Styleguide

public struct CircularWithTitleProgressView: View {
    public var progress: Double
    public var title: String
    public var size: CGFloat = 24
    public var tintColor: Color
    public var fontWeight: Font.Weight
    public var image: Image?
    
    public var body: some View {
        ZStack {
            // Background Circle
            if let image {
                tintColor
                    .opacity(0.3)
                    .clipShape(Circle())
                image
            }
            
            Circle()
                .stroke(
                    Color.gray.opacity(0.2),
                    lineWidth: 2
                )
            
            // Progress Circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [tintColor],
                        center: .center
                    ),
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            
            // Percentage Label
            Text(title)
                .customFont(.caption2, weight: fontWeight)
                .opacity(image == nil ? 1 : 0)
        }
        .frame(width: size, height: size)
    }
}

