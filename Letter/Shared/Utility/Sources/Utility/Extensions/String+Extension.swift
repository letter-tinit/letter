//
//  String+Extension.swift
//  Letter
//
//  Created by TiniT on 9/7/26.
//

import Foundation

public extension String {
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
        guard let flatValue = flatAmountString(),
              !flatValue.isEmpty,
              let value = Decimal(
                string: flatValue,
                locale: Locale(identifier: "en_US_POSIX")
              ),
              value >= .zero
                else {
            return .zero
        }
        
        return value
    }
    
    var titleCase: String {
        self.capitalized
    }
}

extension Optional where Wrapped == String {
    public var isNullOrEmpty: Bool {
        switch self {
        case .none:
            return true
        case .some(let value):
            return value.isEmpty
        }
    }
}

private extension String {
    func flatAmountString() -> String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmed.isEmpty else {
            return nil
        }
        
        // Allow digits and grouping separators only.
        let allowedCharacters = CharacterSet(charactersIn: "0123456789,")
        
        guard trimmed.unicodeScalars.allSatisfy({
            allowedCharacters.contains($0)
        }) else {
            return nil
        }
        
        // Remove grouping separators before parsing.
        return trimmed.replacingOccurrences(of: ",", with: "")
    }
}
