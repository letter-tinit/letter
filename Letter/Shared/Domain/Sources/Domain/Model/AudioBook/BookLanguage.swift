public enum BookLanguage: String, Codable, Sendable, CaseIterable, Hashable {
    case vietnamese
    case english

    public nonisolated var languageCode: String {
        switch self {
        case .vietnamese: "vi-VN"
        case .english: "en-US"
        }
    }

    public nonisolated init?(languageCode: String) {
        let code = languageCode.lowercased()
        if code.hasPrefix("vi") { self = .vietnamese }
        else if code.hasPrefix("en") { self = .english }
        else { return nil }
    }
}
