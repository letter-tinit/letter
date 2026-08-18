//
//  UIScreen+Extension.swift
//  CineTrack
//
//  Created by TiniT on 6/4/26.
//

import UIKit

extension UIScreen {
    static var current: UIScreen {
        UIWindow.current?.screen ?? fallback
    }
    
    private static var fallback: UIScreen {
        UIScreen.screens2.first ?? UIScreen()
    }
}


private protocol SilenceDeprecationForUIScreenWindows {
    var screens: [UIScreen] { get }
}

private final class SilenceDeprecationForUIScreenWindowsImplementation: SilenceDeprecationForUIScreenWindows {
    @available(iOS, deprecated: 16)
    var screens: [UIScreen] { UIScreen.screens }
}

extension UIScreen {
    static var screens2: [UIScreen] {
        (SilenceDeprecationForUIScreenWindowsImplementation() as SilenceDeprecationForUIScreenWindows).screens
    }
}
