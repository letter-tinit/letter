//
//  Modifier.swift
//  Letter
//
//  Created by TiniT on 21/7/26.
//

import SwiftUI
import Domain
import Utility

// MARK: - Confirmation dialog
public struct ConfirmationDialogAction {
    let title: String
    let role: ButtonRole?
    let action: () -> Void

    public init(
        _ title: String,
        role: ButtonRole? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.role = role
        self.action = action
    }
}

public struct ConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let actions: [ConfirmationDialogAction]

    public func body(content: Content) -> some View {
        content.confirmationDialog(
            title,
            isPresented: $isPresented,
            titleVisibility: .visible
        ) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                Button(item.title, role: item.role, action: item.action)
            }
        } message: {
            Text(message)
        }
    }
}

// MARK: - Delete confirmation
public struct DeleteConfirmationDialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let deleteTitle: String
    let deleteAction: () -> Void
    let additionalDeleteActions: [ConfirmationDialogAction]
    public var cancelAction: (() -> Void)?
    
    public func body(content: Content) -> some View {
        content.modifier(
            ConfirmationDialogModifier(
                isPresented: $isPresented,
                title: title,
                message: message,
                actions: [
                    ConfirmationDialogAction(deleteTitle, role: .destructive, action: deleteAction)
                ] + additionalDeleteActions + [
                    ConfirmationDialogAction("common.cancel".localized, role: .cancel) {
                        cancelAction?()
                    }
                ]
            )
        )
    }
}

// MARK: - Toast message
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
