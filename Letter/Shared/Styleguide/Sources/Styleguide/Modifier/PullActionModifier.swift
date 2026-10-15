//
//  PullActionModifier.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 13/10/26.
//

import SwiftUI

private struct PullActionModifier<Indicator: View>: ViewModifier {
    private let isEnabled: Bool
    private let threshold: CGFloat
    private let revertedIndicatorSpacing: CGFloat
    
    let action: () async -> Void
    let indicator: (PullActionState) -> Indicator
    
    @State private var pullDistance: CGFloat = 0
    @State private var isPerforming = false
    
    init(
        isEnabled: Bool,
        threshold: CGFloat,
        revertedIndicatorSpacing: CGFloat,
        action: @escaping () async -> Void,
        @ViewBuilder indicator: @escaping (PullActionState) -> Indicator
    ) {
        self.isEnabled = isEnabled
        self.threshold = max(1, threshold)
        self.revertedIndicatorSpacing = revertedIndicatorSpacing
        self.action = action
        self.indicator = indicator
    }
    
    private var state: PullActionState {
        if isPerforming {
            return .performing
        }
        
        if pullDistance >= threshold {
            return .ready
        }
        
        return .pulling
    }
    
    private var visibleHeight: CGFloat {
        guard isPerforming else {
            return min(pullDistance, threshold)
        }
        
        return threshold
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if isEnabled {
                    indicator(state)
                        .frame(maxWidth: .infinity)
                        .frame(height: threshold)
                        .clipped()
                        .offset(y: -threshold + visibleHeight + revertedIndicatorSpacing)
                        .frame(height: threshold, alignment: .top)
                        .clipped()
                        .allowsHitTesting(false)
                        .accessibilityHidden(
                            pullDistance == 0 && !isPerforming
                        )
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, offset in
                let newDistance = max(0, -offset)
                
                if pullDistance < threshold && newDistance >= threshold && isEnabled {
                    Haptic.impact()
                }
                
                pullDistance = newDistance
            }
            .onScrollPhaseChange { oldPhase, newPhase, context in
                guard isEnabled,
                      oldPhase == .interacting,
                      newPhase != .interacting,
                      !isPerforming else {
                    return
                }
                
                let offset = context.geometry.contentOffset.y
                + context.geometry.contentInsets.top
                
                let releasedDistance = max(0, -offset)
                
                guard releasedDistance >= threshold else {
                    return
                }
                
                Task { @MainActor in
                    guard !isPerforming else {
                        return
                    }
                    
                    isPerforming = true
                    
                    defer {
                        isPerforming = false
                        pullDistance = 0
                    }
                    
                    await action()
                }
            }
    }
}

public extension View {
    func pullAction<Indicator: View>(
        threshold: CGFloat = 115,
        isEnabled: Bool = true,
        revertedIndicatorSpacing: CGFloat = 0,
        action: @escaping () async -> Void,
        @ViewBuilder indicator: @escaping (PullActionState) -> Indicator
    ) -> some View {
        modifier(
            PullActionModifier(
                isEnabled: isEnabled,
                threshold: threshold,
                revertedIndicatorSpacing: revertedIndicatorSpacing,
                action: action,
                indicator: indicator
            )
        )
    }
}
