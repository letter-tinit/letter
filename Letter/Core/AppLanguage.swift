//
//  AppLanguage.swift
//  Letter
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    case vietnamese = "vi"

    static let preferenceKey = "app.language"

    var id: String { rawValue }

    var locale: Locale {
        switch self {
        case .system:
            .autoupdatingCurrent
        case .english:
            Locale(identifier: "en")
        case .vietnamese:
            Locale(identifier: "vi")
        }
    }

    var localizationKey: String {
        switch self {
        case .system:
            "language.system"
        case .english:
            "language.english"
        case .vietnamese:
            "language.vietnamese"
        }
    }

    static var selected: AppLanguage {
        let value = UserDefaults.standard.string(forKey: preferenceKey) ?? system.rawValue
        return AppLanguage(rawValue: value) ?? .system
    }

    var bundle: Bundle? {
        guard self != .system,
              let path = Bundle.main.path(forResource: rawValue, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)
    }
}
