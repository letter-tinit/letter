public enum AppColorScheme: String, Codable, CaseIterable, Identifiable {
    case light
    case dark

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .light: "habit.appearance.light"
        case .dark: "habit.appearance.dark"
        }
    }
}
