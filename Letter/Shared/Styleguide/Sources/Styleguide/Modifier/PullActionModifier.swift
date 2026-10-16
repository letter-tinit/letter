//
//  PullActionModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 16/10/26.
//

import SwiftUI

// MARK: - Modifier
/// Modifier "kéo xuống rồi thả để chạy action", dùng được với ScrollView và List.
/// Phải gắn trực tiếp lên ScrollView / List.
/// Yêu cầu iOS 18 / macOS 15 (onScrollGeometryChange, onScrollPhaseChange).
@available(iOS 18.0, macOS 15.0, *)
struct PullActionModifier<Indicator: View>: ViewModifier {
    let threshold: CGFloat
    let bounceAlways: Bool
    /// `false` → tắt hẳn thao tác kéo: không đo, không haptic, không indicator, không chạy action.
    let isEnabled: Bool
    let action: () -> Void
    let indicator: (PullActionState) -> Indicator

    @State private var progress: CGFloat = 0
    @State private var isArmed = false
    /// Chặn việc "armed" lại trong lúc scroll view đang bounce về.
    @State private var didTrigger = false

    private var state: PullActionState {
        if !isEnabled || didTrigger { return .idle }
        if isArmed { return .armed }
        return progress > 0 ? .pulling(progress: progress) : .idle
    }

    private func reset() {
        progress = 0
        isArmed = false
        didTrigger = false
    }

    func body(content: Content) -> some View {
        content
            // Khi tắt, trả bounce về mặc định để list ngắn không bị ép bounce vô ích.
            .scrollBounceBehavior(isEnabled && bounceAlways ? .always : .automatic)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                guard isEnabled else { return }

                let overscroll = max(-offset, 0)
                if overscroll == 0 { didTrigger = false }

                progress = min(overscroll / threshold, 1)
                isArmed = progress >= 1 && !didTrigger
            }
            .onScrollPhaseChange { oldPhase, newPhase in
                guard isEnabled else { return }

                if newPhase == .interacting {
                    didTrigger = false
                }
                // Thả tay khi đang armed → chạy action đúng 1 lần.
                if oldPhase == .interacting, newPhase != .interacting, isArmed {
                    didTrigger = true
                    isArmed = false
                    action()
                }
            }
            // Bị tắt giữa chừng (đang kéo dở) → dọn state, không để indicator kẹt lại.
            .onChange(of: isEnabled) { _, enabled in
                if !enabled { reset() }
            }
            .overlay(alignment: .top) {
                indicator(state)
                    .allowsHitTesting(false)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .padding(.top, 8)
                    .opacity(isEnabled ? progress : 0)
                    .scaleEffect(0.7 + 0.3 * progress)
                    .offset(y: -20 * (1 - progress))
                    .animation(.spring(duration: 0.25), value: isArmed)
            }
            .sensoryFeedback(.impact(weight: .light), trigger: isArmed) { _, new in new }
    }
}

// MARK: - View API
@available(iOS 18.0, macOS 15.0, *)
public extension View {
    /// Indicator tự vẽ, nhận `PullActionState`.
    /// - Parameter isEnabled: `false` để tắt thao tác kéo (mặc định `true`).
    func onPullAction<Indicator: View>(
        threshold: CGFloat = 80,
        bounceAlways: Bool = true,
        isEnabled: Bool = true,
        action: @escaping () -> Void,
        @ViewBuilder indicator: @escaping (PullActionState) -> Indicator
    ) -> some View {
        modifier(
            PullActionModifier(
                threshold: threshold,
                bounceAlways: bounceAlways,
                isEnabled: isEnabled,
                action: action,
                indicator: indicator
            )
        )
    }

    /// Indicator mặc định.
    /// - Parameter isEnabled: `false` để tắt thao tác kéo (mặc định `true`).
    func onPullAction(
        _ indicatorStyle: DefaultPullActionStyle = .label,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        onPullAction(isEnabled: isEnabled, action: action) { state in
            DefaultPullActionIndicator(
                defaultPullActionStyle: indicatorStyle,
                state: state
            )
        }
    }
}
