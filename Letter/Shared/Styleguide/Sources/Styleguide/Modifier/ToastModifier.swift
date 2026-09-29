//
//  ToastModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 29/9/26.
//

import SwiftUI

public struct ToastModifier: ViewModifier {
    @State private var visibleMessage: ToastMessage?
    
    let message: ToastMessage?
    let position: Alignment
    let duration: Double

    public func body(content: Content) -> some View {
        content
            .overlay(alignment: position) {
                if let visibleMessage {
                    let toastType = visibleMessage.type
                    HStack {
                        Image(systemName: toastType.icon)
                            .resizable()
                            .frame(width: 24, height: 24)
                        
                        Text(visibleMessage.text)
                            .customFont(.subheadline, weight: .semibold)
                            .lineLimit(nil)
                        
                        Spacer()
                    }
                    .foregroundStyle(toastType.color)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        Capsule()
                            .foregroundStyle(toastType.color.opacity(0.2))
                    )
                    .padding(.horizontal)
                    .padding(position == .top ? .top : .bottom, 8)
                    .transition(.move(edge: position == .top ? .top : .bottom).combined(with: .opacity))
                    .zIndex(1)
                }
            }
            .onChange(of: message) { _, newValue in
                guard let newValue else { return }
                
                makeHaptic(newValue.type)

                visibleMessage = newValue

                Task {
                    try? await Task.sleep(for: .seconds(duration))

                    await MainActor.run {
                        if visibleMessage?.id == newValue.id {
                            visibleMessage = nil
                        }
                    }
                }
            }
            .animation(.easeInOut, value: visibleMessage)
    }
    
    private func makeHaptic(_ toastType: ToastType) {
        switch toastType {
        case .success:
            Haptic.success()
        case .failure:
            Haptic.error()
        case .warning:
            Haptic.warning()
        case .info:
            Haptic.info()
        }
    }
}

public extension View {
    func toast(
        message: ToastMessage?,
        position: Alignment = .top,
        duration: Double = 3
    ) -> some View {
        modifier(
            ToastModifier(
                message: message,
                position: position,
                duration: duration
            )
        )
    }
}
