//
//  Haptic.swift
//  Letter
//
//  Created by TiniT on 20/5/26.
//

import UIKit
import Domain
import Core
import Utility

public enum Haptic {
    public static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    public static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }

    public static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - HAPTIC STYLE
extension Haptic {
    public static func success() {
        notification(.success)
    }
    
    public static func warning() {
        notification(.warning)
    }
    
    public static func error() {
        notification(.error)
    }
    
    public static func info() {
        notification(.warning)
    }
}
