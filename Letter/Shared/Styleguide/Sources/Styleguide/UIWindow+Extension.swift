//
//  UIWindow+Extension.swift
//  CineTrack
//
//  Created by TiniT on 6/4/26.
//

import UIKit
import Domain
import Core
import Utility

extension UIWindow {
    public static var current: UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScence = scene as? UIWindowScene else { continue }
            for window in windowScence.windows {
                if window.isKeyWindow {
                    return window
                }
            }
        }
        return nil
    }
}
