//
//  Double+Extension.swift
//  Letter
//
//  Created by TiniT on 10/7/26.
//

import Foundation

extension Double {
    var ceiledToTwoDecimalPlaces: Double {
        ceil(self * 100) / 100
    }

    
    /// Remove uneeded 0 degit
    var cleanString: String {
        formatted(
            .number
                .precision(.fractionLength(0...10))
        )
    }
}
