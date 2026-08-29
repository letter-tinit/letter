enum AppColorScheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "habit.appearance.light"
        case .dark: "habit.appearance.dark"
        }
    }
}
