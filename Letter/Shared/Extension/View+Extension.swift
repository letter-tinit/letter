//
//  View+Extension.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI
import UIKit

extension View {
    // MARK: - Background Style
    @ViewBuilder
    func borderedBackground(
        linearGradient: LinearGradient? = nil,
        fillColor: Color = .clear,
        borderColor: Color = Color.Common.border,
        cornerRadius: CGFloat = 16,
        lineWidth: CGFloat = 1
    ) -> some View {
        if let linearGradient {
            background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(linearGradient)
                    .stroke(
                        borderColor,
                        lineWidth: lineWidth
                    )
            }
        } else {
            background {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(fillColor)
                    .stroke(
                        borderColor,
                        lineWidth: lineWidth
                    )
            }
        }
    }
    
    // MARK: - Animation
    func baseAnimation(_ changes: @escaping () -> Void) {
        withAnimation(.spring(duration: 0.3)) {
            changes()
        }
    }
    
    // MARK: - Keyboard
    func dismissKeyboardOnTap() -> some View {
        self.background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.dismissKeyboard()
                }
        }
    }

    func clearDefaultConfigure() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button("Done") {
                    UIApplication.shared.dismissKeyboard()
                }
            }
        }
    }
    
    func currencyInputFormat(_ text: Binding<String>) -> some View {
        modifier(CurrencyInputModifier(text: text))
    }
    
    // MARK: - Font Style
    func customLargeTitle() -> some View {
        self
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    func customTitle() -> some View {
        self
            .font(.title)
            .fontWeight(.bold)
    }
    
    func customSubTitle() -> some View {
        self
            .font(.system(size: 20))
            .fontWeight(.bold)
    }
    
    func customHeadline() -> some View {
        self
            .font(.headline)
            .fontWeight(.semibold)
    }
    
    func customSubHeadline() -> some View {
        self
            .font(.subheadline)
            .fontWeight(.semibold)
    }
    
    func secondarySubHeadline() -> some View {
        self
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }
    
    func customNormalText() -> some View {
        self
            .font(.default)
            .fontWeight(.regular)
    }
    
    func customSubText() -> some View {
        self
            .font(.subheadline)
            .fontWeight(.regular)
    }
    
    // MARK: - Modifier
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
    
    func cardStyle(_ gradient: Gradient) -> some View {
        self
            .shadow(color: .primary.opacity(0.3), radius: 1, x: 1, y: 1)
            .borderedBackground(
                linearGradient: LinearGradient(
                    gradient: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cornerRadius: 16,
                lineWidth: 0
            )
    }
}

struct AppList<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        List {
            content
                .listRowInsets(EdgeInsets())
                .clearDefaultConfigure()
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .scrollBounceBehavior(.basedOnSize)
    }
}
