//
//  CircularWithTitleProgressView.swift
//  Habit
//
//  Created by TiniT on 29/4/26.
//

import SwiftUI

struct CircularWithTitleProgressView: View {
    var progress: Double
    var title: String
    var size: CGFloat = 24
    var tintColor: Color
    var fontWeight: Font.Weight
    var image: Image?
    
    var body: some View {
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
                    tintColor,
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: progress)
            
            // Percentage Label
            Text(title)
                .font(.caption2)
                .fontWeight(fontWeight)
                .fontDesign(.rounded)
                .opacity(image == nil ? 1 : 0)
        }
        .frame(width: size, height: size)
    }
}

#Preview {
    CircularWithTitleProgressView(progress: 0.5, title: "29", tintColor: .creamWhite, fontWeight: .bold)
}
