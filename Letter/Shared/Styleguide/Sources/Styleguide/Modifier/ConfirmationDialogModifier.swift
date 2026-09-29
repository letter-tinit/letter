//
//  ConfirmationDialogModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 29/9/26.
//

import SwiftUI

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

public extension View {
    func commonConfirmationDialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String,
        actions: [ConfirmationDialogAction]
    ) -> some View {
        modifier(
            ConfirmationDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                actions: actions
            )
        )
    }
}
