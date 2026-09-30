import SwiftUI
import UIKit

/// Keeps keyboard controls in the view's safe area. Native keyboard toolbar
/// layout can report invalid frames during focus transitions on iOS 26.
struct KeyboardToolbarModifier: ViewModifier {
    let items: [KeyboardToolbarItem]
    @State private var isKeyboardVisible = false

    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isKeyboardVisible {
                    controls
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(.bar)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                isKeyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                isKeyboardVisible = false
            }
            .onDisappear { isKeyboardVisible = false }
    }

    private var controls: some View {
        HStack {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case let .button(title, visible, action):
                    if visible { Button(title, action: action) }
                case .spacer:
                    Spacer()
                }
            }
            Spacer(minLength: 0)
            Button("Done") {
                UIApplication.shared.dismissKeyboard()
            }
            .accessibilityIdentifier("keyboard.dismiss")
        }
        .customFont(.body)
        .frame(minHeight: 44)
    }
}
