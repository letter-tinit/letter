//
//  Decimal+Extension.swift
//  Letter
//
//  Created by TiniT on 10/7/26.
//

import Foundation

public extension Decimal {
    var formattedVND: String {
        let priceNumber = NSDecimalNumber(decimal: self)
        
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        
        if let result = formatter.string(from: priceNumber) {
            return result + "₫"
        }
        
        return ""
    }
    
    var toAmountString: String {
        let priceNumber = NSDecimalNumber(decimal: self)
        
        let formatter = NumberFormatter()
        formatter.groupingSeparator = ","
        formatter.groupingSize = 3
        formatter.usesGroupingSeparator = true
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.numberStyle = .none
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: priceNumber) ?? ""
    }
    
    var doubleValue: Double {
        NSDecimalNumber(decimal: self).doubleValue
    }
}
