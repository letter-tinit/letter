//
//  AppLanguage.swift
//  Letter
//

import Foundation

public enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case vietnamese = "vi"

    public static let preferenceKey = "app.language"

    public var id: String { rawValue }

    public var shortCode: String {
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

    public var locale: Locale {
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

    public static var selected: AppLanguage {
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
