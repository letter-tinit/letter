//
//  UIApplication+Extension.swift
//  Habit
//
//  Created by TiniT on 20/5/26.
//

import UIKit

extension UIApplication {
    func dismissKeyboard() {
        sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
}
