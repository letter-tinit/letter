//
//  DefaultPullActionIndicator.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 16/10/26.
//

import SwiftUI

public enum DefaultPullActionStyle {
    case label
    case icon
}

struct DefaultPullActionIndicator: View {
    let defaultPullActionStyle: DefaultPullActionStyle
    let state: PullActionState
    
    var body: some View {
        switch defaultPullActionStyle {
        case .label:
            DefaultPullActionLabelStyleIndicator(state: state)
        case .icon:
            DefaultPullActionIconStyleIndicator(state: state)
        }
    }
}

// MARK: - Default indicator
struct DefaultPullActionLabelStyleIndicator: View {
    let state: PullActionState
    var idleText = "common.pull.toCreate".localized
    var armedText = "common.release.toCreate".localized
    var systemImage = "plus.circle.fill"
    
    private var isArmed: Bool { state == .armed }
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .symbolEffect(.bounce, value: isArmed)
                .foregroundStyle(isArmed ? Color.Common.success : .secondary)
            
            Text(isArmed ? armedText : idleText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isArmed ? Color.Common.success : .secondary)
        }
        .padding(8)
        .appGlassEffect(
            .regular.tint(isArmed ? Color.Common.success.opacity(0.2) : .clear),
            in: .capsule
        )
    }
}

struct DefaultPullActionIconStyleIndicator: View {
    let state: PullActionState
    
    private var isArmed: Bool { state == .armed }
    
    var body: some View {
        Image(systemName: "plus")
            .padding()
            .appGlassEffect(
                .regular.tint(isArmed ? Color.Common.success.opacity(0.2) : .clear),
                in: .circle
            )
            .foregroundStyle(isArmed ? Color.Common.success : .secondary)
    }
}
