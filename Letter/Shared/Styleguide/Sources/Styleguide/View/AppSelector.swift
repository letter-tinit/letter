import SwiftUI
import Foundation
import Domain
import Utility

public enum AppSelectorIconPosition: Equatable { case left, right }
public enum AppSelectorIcon { case asset(String), system(String) }

public enum AppSelectorStyle {
    case labelIcon
    case iconToggle
    case labelToggle
}

public struct AppSelector: View {
    private let style: AppSelectorStyle
    private let label: String?
    private let icon: AppSelectorIcon
    private let iconPosition: AppSelectorIconPosition
    private let iconSize: CGFloat
    private let isLeadingIcon: Bool
    private let padding: CGFloat
    private let width: CGFloat
    private let isOn: Bool
    private let trackColor: Color
    private let iconColor: Color
    private let action: () -> Void
    
    public init(
        style: AppSelectorStyle,
        label: String? = nil,
        icon: AppSelectorIcon = .system(""),
        iconPosition: AppSelectorIconPosition = .left,
        iconSize: CGFloat = 28,
        padding: CGFloat = 6,
        width: CGFloat = 78,
        isLeadingIcon: Bool = false,
        isOn: Bool = false,
        trackColor: Color = .clear,
        iconColor: Color = .secondary,
        action: @escaping () -> Void
    ) {
        self.style = style
        self.label = label
        self.icon = icon
        self.iconPosition = iconPosition
        self.iconSize = iconSize
        self.padding = padding
        self.width = width
        self.isLeadingIcon = isLeadingIcon
        self.isOn = isOn
        self.trackColor = trackColor
        self.iconColor = iconColor
        self.action = action
    }
    
    public var body: some View {
        switch style {
        case .labelIcon: labelIconSelector
        case .iconToggle: iconToggleSelector
        case .labelToggle: labelToggleSelector
        }
    }
    
    private var labelIconSelector: some View {
        Button(action: select) {
            HStack {
                if iconPosition == .left {
                    iconView
                    Spacer()
                    labelView.padding(.trailing, 4)
                } else {
                    labelView.padding(.leading, 4)
                    Spacer()
                    iconView
                }
            }
            .padding(padding)
            .frame(width: width)
            .animation(.spring(response: 0.28, dampingFraction: 0.78), value: iconPosition)
        }
        .buttonStyle(.plain)
    }
    
    private var iconToggleSelector: some View {
        Button(action: select) {
            HStack(alignment: .center) {
                if isLeadingIcon {
                    iconView
                    Spacer()
                    knob
                } else {
                    knob
                    Spacer()
                    iconView
                }
            }
            .padding(padding)
            .appGlassEffect(
                .regular.interactive().tint(trackColor),
                in: Capsule()
            )
            .frame(width: width)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: isLeadingIcon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isLeadingIcon ? "Light" : "Dark")
    }
    
    private var labelToggleSelector: some View {
        Button(action: select) {
            HStack(alignment: .center) {
                if isOn {
                    labelView
                    Spacer()
                    knob
                } else {
                    knob
                    Spacer()
                    labelView
                }
            }
            .padding(padding)
            .appGlassEffect(
                .regular.interactive().tint(trackColor),
                in: Capsule()
            )
            .frame(width: width)
            .animation(.spring(response: 0.30, dampingFraction: 0.78), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label ?? "")
    }
    
    private func select() {
        withAnimation(.spring(response: 0.30, dampingFraction: 0.78)) { action() }
        Haptic.selection()
    }
    
    private var labelView: some View {
        Text(displayLabel)
            .customFont(size: 17, weight: .semibold)
            .foregroundStyle(.secondary)
            .lineLimit(1)
    }
    
    private var displayLabel: String {
        String(
            (label ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .prefix(2)
        )
        .uppercased()
    }
    
    private var iconView: some View {
        Group {
            switch icon {
            case .asset(let name): Image(name).resizable().scaledToFit()
            case .system(let name): Image(systemName: name).font(.system(size: iconSize - 8, weight: .medium))
            }
        }
        .frame(width: iconSize, height: iconSize)
        .foregroundStyle(iconColor)
    }
    
    private var knob: some View {
        Circle().fill(.white)
            .frame(width: iconSize, height: iconSize)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
    }
}
