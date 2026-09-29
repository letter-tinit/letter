//
//  DeleteConfirmationDialogModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 29/9/26.
//

import SwiftUI
import Utility

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

public extension View {
    func deleteConfirmationDialog(
        isPresented: Binding<Bool>,
        title: String = "common.delete.title".localized,
        message: String = "common.delete.warning".localized,
        deleteTitle: String = "common.delete".localized,
        deleteAction: @escaping () -> Void,
        additionalDeleteActions: [ConfirmationDialogAction] = [],
        cancelAction: (() -> Void)? = nil
    ) -> some View {
        modifier(
            DeleteConfirmationDialogModifier(
                isPresented: isPresented,
                title: title,
                message: message,
                deleteTitle: deleteTitle,
                deleteAction: deleteAction,
                additionalDeleteActions: additionalDeleteActions,
                cancelAction: cancelAction
            )
        )
    }
}
