//
//  String+Extension.swift
//  Letter
//
//  Created by TiniT on 9/7/26.
//

import Foundation

extension String {
    /// Localize a string using your JSON File
    /// If the key is not found return the same key
    /// that prevent replace untagged values
    ///
    /// - returns: localized key or same text
    var localized: String {
        if let bundle = AppLanguage.selected.bundle {
            return NSLocalizedString(self, bundle: bundle, comment: "")
        }

        return NSLocalizedString(self, comment: "")
    }

    func localized(_ arguments: CVarArg...) -> String {
        String(format: localized, locale: AppLanguage.selected.locale, arguments: arguments)
    }
    
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
    
    func toDecimal() -> Decimal {
        Decimal(string: self) ?? 0
    }
}

extension Optional where Wrapped == String {
    var isNullOrEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.isEmpty
        }
    }
}
