//
//  AppLanguage.swift
//  Letter
//

import Foundation

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"

    static let preferenceKey = "app.language"

    var id: String { rawValue }

    var shortCode: String {
        switch self {
        case .english: "EN"
        case .vietnamese: "VI"
        }
    }

    var flag: String {
        switch self {
        case .english: "🇬🇧"
        case .vietnamese: "🇻🇳"
        }
    }

    var locale: Locale {
        switch self {
        case .english:
            Locale(identifier: "en")
        case .vietnamese:
            Locale(identifier: "vi")
        }
    }

    var localizationKey: String {
        switch self {
        case .english:
            "language.english"
        case .vietnamese:
            "language.vietnamese"
        }
    }

    static var selected: AppLanguage {
        let value = UserDefaults.standard.string(forKey: preferenceKey) ?? vietnamese.rawValue
        return AppLanguage(rawValue: value) ?? .vietnamese
    }

    var bundle: Bundle? {
        guard let path = Bundle.main.path(forResource: rawValue, ofType: "lproj") else {
            return nil
        }

        return Bundle(path: path)
    }
}
