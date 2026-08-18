//
//  Color+Extension.swift
//  Habit
//
//  Created by TiniT on 28/4/26.
//

import SwiftUI

extension Color {
    struct Common {
        static let border = Color(uiColor: .separator)
        static let background = Color(uiColor: .systemGroupedBackground)
        static let surface = Color(uiColor: .secondarySystemGroupedBackground)
        static let success = Color.green
        static let failure = Color.red
    }

    init(hex: String) {
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
    static let skyBlue = Color(hex: "#87CEEB")
    static let royalBlue = Color(hex: "#4169E1")
    static let midnightBlue = Color(hex: "#191970")
    static let iceBlue = Color(hex: "#D6F6FF")
    
    // Greens
    static let emeraldGreen = Color(hex: "#50C878")
    static let forestGreen = Color(hex: "#228B22")
    static let limeGreen = Color(hex: "#32CD32")
    static let sageGreen = Color(hex: "#9CAF88")
    
    // Reds / Pinks
    static let rubyRed = Color(hex: "#E0115F")
    static let rosePink = Color(hex: "#FF66B2")
    static let blushPink = Color(hex: "#F8C8DC")
    static let crimsonRed = Color(hex: "#DC143C")
    
    // Oranges / Yellows
    static let sunsetOrange = Color(hex: "#FD5E53")
    static let peachOrange = Color(hex: "#FFCBA4")
    static let goldenYellow = Color(hex: "#FFD700")
    static let mustardYellow = Color(hex: "#E1AD01")
    
    // Purples
    static let lavenderPurple = Color(hex: "#E6E6FA")
    static let deepPurple = Color(hex: "#673AB7")
    static let violetPurple = Color(hex: "#8F00FF")
    static let plumPurple = Color(hex: "#8E4585")
    
    // Neutral
    static let charcoalGray = Color(hex: "#36454F")
    static let warmGray = Color(hex: "#A89F91")
    static let creamWhite = Color(hex: "#FFFDD0")
    static let richBlack = Color(hex: "#0D0D0D")
    
    // Teal / Cyan
    static let oceanTeal = Color(hex: "#008080")
    static let aquaCyan = Color(hex: "#00FFFF")
    static let turquoise = Color(hex: "#40E0D0")
    
    // Brown
    static let coffeeBrown = Color(hex: "#6F4E37")
    static let caramelBrown = Color(hex: "#C68E17")
    static let chocolateBrown = Color(hex: "#7B3F00")
}

extension Habit {
    var gradient: LinearGradient {
        let colors = GradientProvider.gradient(for: colorHex)

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

enum GradientProvider {
    static func gradient(for hex: String) -> [Color] {
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
