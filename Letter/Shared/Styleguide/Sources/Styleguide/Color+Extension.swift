//
//  Color+Extension.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI
import Domain
import Utility

extension Color {
    public struct Common {
        public static let border = Color(uiColor: .separator)
        public static let background = Color(uiColor: .systemGroupedBackground)
        public static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        public static let label = Color(uiColor: .systemGroupedBackground)
        public static let success = Color.green
        public static let failure = Color.red
    }
    
    struct UIColor {
            // MARK: - Label
            static let label = Color(uiColor: .label)
            static let secondaryLabel = Color(uiColor: .secondaryLabel)
            static let tertiaryLabel = Color(uiColor: .tertiaryLabel)
            static let quaternaryLabel = Color(uiColor: .quaternaryLabel)

            // MARK: - Fill
            static let fill = Color(uiColor: .systemFill)
            static let secondaryFill = Color(uiColor: .secondarySystemFill)
            static let tertiaryFill = Color(uiColor: .tertiarySystemFill)
            static let quaternaryFill = Color(uiColor: .quaternarySystemFill)

            // MARK: - Text
            static let placeholderText = Color(uiColor: .placeholderText)

            // MARK: - Tint
            static let tint = Color(uiColor: .tintColor)

            // MARK: - Background
            static let background = Color(uiColor: .systemBackground)
            static let secondaryBackground = Color(uiColor: .secondarySystemBackground)
            static let tertiaryBackground = Color(uiColor: .tertiarySystemBackground)

            // MARK: - Grouped Background
            static let groupedBackground = Color(uiColor: .systemGroupedBackground)
            static let secondaryGroupedBackground = Color(uiColor: .secondarySystemGroupedBackground)
            static let tertiaryGroupedBackground = Color(uiColor: .tertiarySystemGroupedBackground)

            // MARK: - Separator
            static let separator = Color(uiColor: .separator)
            static let opaqueSeparator = Color(uiColor: .opaqueSeparator)

            // MARK: - Link
            static let link = Color(uiColor: .link)

            // MARK: - System Colors
            static let red = Color(uiColor: .systemRed)
            static let orange = Color(uiColor: .systemOrange)
            static let yellow = Color(uiColor: .systemYellow)
            static let green = Color(uiColor: .systemGreen)
            static let mint = Color(uiColor: .systemMint)
            static let teal = Color(uiColor: .systemTeal)
            static let cyan = Color(uiColor: .systemCyan)
            static let blue = Color(uiColor: .systemBlue)
            static let indigo = Color(uiColor: .systemIndigo)
            static let purple = Color(uiColor: .systemPurple)
            static let pink = Color(uiColor: .systemPink)
            static let brown = Color(uiColor: .systemBrown)

            // MARK: - System Gray
            static let gray = Color(uiColor: .systemGray)
            static let gray2 = Color(uiColor: .systemGray2)
            static let gray3 = Color(uiColor: .systemGray3)
            static let gray4 = Color(uiColor: .systemGray4)
            static let gray5 = Color(uiColor: .systemGray5)
            static let gray6 = Color(uiColor: .systemGray6)

            // MARK: - Fixed Colors
            static let black = Color(uiColor: .black)
            static let darkGray = Color(uiColor: .darkGray)
            static let lightGray = Color(uiColor: .lightGray)
            static let white = Color(uiColor: .white)

            static let fixedRed = Color(uiColor: .red)
            static let fixedOrange = Color(uiColor: .orange)
            static let fixedYellow = Color(uiColor: .yellow)
            static let fixedGreen = Color(uiColor: .green)
            static let fixedBlue = Color(uiColor: .blue)
            static let fixedCyan = Color(uiColor: .cyan)
            static let fixedPurple = Color(uiColor: .purple)
            static let magenta = Color(uiColor: .magenta)

            // MARK: - Nonadaptive Text
            static let darkText = Color(uiColor: .darkText)
            static let lightText = Color(uiColor: .lightText)

            // MARK: - Transparent
            static let clear = Color(uiColor: .clear)
        }

    public init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255,
                            (int >> 8) * 17,
                            (int >> 4 & 0xF) * 17,
                            (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255,
                            int >> 16,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24,
                            int >> 16 & 0xFF,
                            int >> 8 & 0xFF,
                            int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // Blues
    public static let skyBlue = Color(hex: "#87CEEB")
    public static let royalBlue = Color(hex: "#4169E1")
    public static let midnightBlue = Color(hex: "#191970")
    public static let iceBlue = Color(hex: "#D6F6FF")
    
    // Greens
    public static let emeraldGreen = Color(hex: "#50C878")
    public static let forestGreen = Color(hex: "#228B22")
    public static let limeGreen = Color(hex: "#32CD32")
    public static let sageGreen = Color(hex: "#9CAF88")
    
    // Reds / Pinks
    public static let rubyRed = Color(hex: "#E0115F")
    public static let rosePink = Color(hex: "#FF66B2")
    public static let blushPink = Color(hex: "#F8C8DC")
    public static let crimsonRed = Color(hex: "#DC143C")
    
    // Oranges / Yellows
    public static let sunsetOrange = Color(hex: "#FD5E53")
    public static let peachOrange = Color(hex: "#FFCBA4")
    public static let goldenYellow = Color(hex: "#FFD700")
    public static let mustardYellow = Color(hex: "#E1AD01")
    
    // Purples
    public static let lavenderPurple = Color(hex: "#E6E6FA")
    public static let deepPurple = Color(hex: "#673AB7")
    public static let violetPurple = Color(hex: "#8F00FF")
    public static let plumPurple = Color(hex: "#8E4585")
    
    // Neutral
    public static let charcoalGray = Color(hex: "#36454F")
    public static let warmGray = Color(hex: "#A89F91")
    public static let creamWhite = Color(hex: "#FFFDD0")
    public static let richBlack = Color(hex: "#0D0D0D")
    
    // Teal / Cyan
    public static let oceanTeal = Color(hex: "#008080")
    public static let aquaCyan = Color(hex: "#00FFFF")
    public static let turquoise = Color(hex: "#40E0D0")
    
    // Brown
    public static let coffeeBrown = Color(hex: "#6F4E37")
    public static let caramelBrown = Color(hex: "#C68E17")
    public static let chocolateBrown = Color(hex: "#7B3F00")
}

extension HabitSnapshot {
    public var gradient: LinearGradient {
        let colors = GradientProvider.gradient(for: colorHex)

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public enum GradientProvider {
    public static func gradient(for hex: String) -> [Color] {
        switch hex {
        case "#4ECDC4":
            [
                Color(hex: "#8EF2EA"),
                Color(hex: "#7FE7E0")
            ]
        case "#FF6B6B":
            [
                Color(hex: "#FFBABA"),
                Color(hex: "#FFA5A5")
            ]
        case "#FFD93D":
            [
                Color(hex: "#FFF09A"),
                Color(hex: "#FFE985")
            ]
        case "#6C5CE7":
            [
                Color(hex: "#C3B8FF"),
                Color(hex: "#A29BFE")
            ]
        case "#A8E6CF":
            [
                Color(hex: "#D9FFF0"),
                Color(hex: "#C9F7E8")
            ]
        case "#87CEEB":
            [
                Color(hex: "#CFF0FF"),
                Color(hex: "#B7E8FF")
            ]
        case "#FF66B2":
            [
                Color(hex: "#FFC2DD"),
                Color(hex: "#FF9DCC")
            ]
        case "#FD8A5E":
            [
                Color(hex: "#FFD0BC"),
                Color(hex: "#FFAE8B")
            ]
        case "#50C878":
            [
                Color(hex: "#BDF4CB"),
                Color(hex: "#8BE5A8")
            ]
        case "#4169E1":
            [
                Color(hex: "#B9CAFF"),
                Color(hex: "#8EAAFF")
            ]
        case "#E0115F":
            [
                Color(hex: "#FFB0CE"),
                Color(hex: "#F77EAE")
            ]
        case "#8E7DBE":
            [
                Color(hex: "#DCD1FA"),
                Color(hex: "#C2B0ED")
            ]
        case "#FF9F1C":
            [
                Color(hex: "#FFD89B"),
                Color(hex: "#FFC065")
            ]
        case "#7AC74F":
            [
                Color(hex: "#D2F5B6"),
                Color(hex: "#AFE487")
            ]
        default:
            [
                Color.gray.opacity(0.4),
                Color.white
            ]
        }
    }
}
