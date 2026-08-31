//
//  View+Extension.swift
//  Letter
//
//  Created by TiniT on 13/7/26.
//

import SwiftUI
import UIKit
import Domain
import Core
import Utility

extension View {
    // MARK: - Glass Effect
    public func appGlassEffect<S: Shape>(
        _ style: Glass = .regular,
        in shape: S = RoundedRectangle(cornerRadius: 16)
    ) -> some View {
        glassEffect(style, in: shape)
    }

    // MARK: - Background Style
    @ViewBuilder
    public func borderedBackground(
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
    public func baseAnimation(_ changes: @escaping () -> Void) {
        withAnimation(.spring(duration: 0.3)) {
            changes()
        }
    }
    
    // MARK: - Keyboard
    public func dismissKeyboardOnTap() -> some View {
        self.background {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    UIApplication.shared.dismissKeyboard()
                }
        }
    }

    public func clearDefaultConfigure() -> some View {
        listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
    
    public func keyboardDoneButton() -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                
                Button("Done") {
                    UIApplication.shared.dismissKeyboard()
                }
            }
        }
    }
    
    public func appSectionHeaderStyle() -> some View {
        self
            .textCase(nil)
            .customFont(.headline)
            .foregroundStyle(.secondary)
    }
    
    // MARK: - Font Style
    /// Shared typography entry point used by both Finance and Habit.
    /// Keeping the text style dynamic preserves accessibility scaling while
    /// applying the app's rounded design consistently.
    public func customFont(
        _ style: Font.TextStyle,
        weight: Font.Weight? = nil
    ) -> some View {
        if let weight {
            self.font(.system(style, design: .rounded, weight: weight))
        } else {
            self.font(.system(style, design: .rounded))
        }
    }

    /// Fixed-size typography is intentionally separate from semantic styles.
    /// Use this only for visual glyphs/compact charts where no Dynamic Type
    /// style is an appropriate mapping.
    public func customFont(
        size: CGFloat,
        weight: Font.Weight? = nil
    ) -> some View {
        if let weight {
            self.font(.system(size: size, weight: weight, design: .rounded))
        } else {
            self.font(.system(size: size, design: .rounded))
        }
    }

    // MARK: - Modifier
    public func commonConfirmationDialog(
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

    public func deleteConfirmationDialog(
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
    
    public func toast(
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
    
    public func cardStyle(_ gradient: Gradient) -> some View {
        self
            .shadow(color: Color.black.opacity(0.3), radius: 1)
            .borderedBackground(
                linearGradient: LinearGradient(
                    gradient: gradient,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                cornerRadius: 16,
                lineWidth: 0
            )
            .appGlassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: 16)
            )
            .foregroundStyle(Color.UIColor.label)
    }
    
    public func endTapHaptic() -> some View {
        self
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0).onEnded { _ in
                    Haptic.selection()
                }
            )
    }
}

public struct AppList<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
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
