enum BookLanguage: String, Codable, Sendable, CaseIterable, Hashable {
    case vietnamese
    case english

    var languageCode: String {
        switch self {
        case .vietnamese: "vi-VN"
        case .english: "en-US"
        }
    }

    init?(languageCode: String) {
        let code = languageCode.lowercased()
        if code.hasPrefix("vi") { self = .vietnamese }
        else if code.hasPrefix("en") { self = .english }
        else { return nil }
    }
}
