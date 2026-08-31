//
//  UIApplication+Extension.swift
//  Letter
//
//  Created by TiniT on 20/5/26.
//

import UIKit
import Domain
import Utility

extension UIApplication {
    public func dismissKeyboard() {
        sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
