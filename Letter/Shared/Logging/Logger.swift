//
//  Logger.swift
//  Presentation
//
//  Created by Thanh Hải on 2/12/25.
//

import Foundation
#if DEBUG
import os
#endif

@inline(__always)
func logDebug(_ items: Any..., separator: String = " ", terminator: String = "\n") {
#if DEBUG
    print(items, separator: separator, terminator: terminator)
#endif
}

enum Logger {
    static func error(_ message: String) {
        #if DEBUG
        print("[ERROR] \(message)")
        #endif
    }
}
