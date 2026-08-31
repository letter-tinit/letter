//
//  Gradient+Extension.swift
//  Letter
//
//  Created by TiniT on 7/8/26.
//

import SwiftUI
import Domain
import Utility

extension Gradient {
public enum Glass {
        public static let pink = Gradient(stops: [
            .init(color: Color(red: 1.00, green: 0.95, blue: 0.97), location: 0.0),
            .init(color: Color(red: 1.00, green: 0.86, blue: 0.91), location: 0.35),
            .init(color: Color(red: 0.96, green: 0.76, blue: 0.85), location: 0.55),
            .init(color: Color(red: 1.00, green: 0.90, blue: 0.94), location: 0.8),
            .init(color: Color(red: 0.97, green: 0.82, blue: 0.89), location: 1.0)
        ])
        
        public static let blue = Gradient(stops: [
            .init(color: Color(red: 0.95, green: 0.98, blue: 1.00), location: 0.0),
            .init(color: Color(red: 0.84, green: 0.92, blue: 1.00), location: 0.35),
            .init(color: Color(red: 0.70, green: 0.84, blue: 0.98), location: 0.55),
            .init(color: Color(red: 0.90, green: 0.96, blue: 1.00), location: 0.8),
            .init(color: Color(red: 0.80, green: 0.90, blue: 0.99), location: 1.0)
        ])
        
        public static let mint = Gradient(stops: [
            .init(color: Color(red: 0.95, green: 1.00, blue: 0.98), location: 0.0),
            .init(color: Color(red: 0.82, green: 0.96, blue: 0.90), location: 0.35),
            .init(color: Color(red: 0.68, green: 0.90, blue: 0.80), location: 0.55),
            .init(color: Color(red: 0.90, green: 0.99, blue: 0.94), location: 0.8),
            .init(color: Color(red: 0.78, green: 0.93, blue: 0.86), location: 1.0)
        ])
        
        public static let lavender = Gradient(stops: [
            .init(color: Color(red: 0.98, green: 0.96, blue: 1.00), location: 0.0),
            .init(color: Color(red: 0.91, green: 0.84, blue: 0.98), location: 0.35),
            .init(color: Color(red: 0.80, green: 0.70, blue: 0.92), location: 0.55),
            .init(color: Color(red: 0.95, green: 0.90, blue: 1.00), location: 0.8),
            .init(color: Color(red: 0.86, green: 0.78, blue: 0.96), location: 1.0)
        ])
        
        public static let beige = Gradient(stops: [
            .init(color: Color(red: 1.00, green: 0.98, blue: 0.94), location: 0.0),
            .init(color: Color(red: 0.96, green: 0.90, blue: 0.80), location: 0.35),
            .init(color: Color(red: 0.88, green: 0.78, blue: 0.64), location: 0.55),
            .init(color: Color(red: 1.00, green: 0.94, blue: 0.86), location: 0.8),
            .init(color: Color(red: 0.92, green: 0.84, blue: 0.72), location: 1.0)
        ])
        
        public static let gray = Gradient(stops: [
            .init(color: Color(red: 0.98, green: 0.98, blue: 0.99), location: 0.0),
            .init(color: Color(red: 0.86, green: 0.87, blue: 0.90), location: 0.35),
            .init(color: Color(red: 0.72, green: 0.74, blue: 0.78), location: 0.55),
            .init(color: Color(red: 0.94, green: 0.95, blue: 0.97), location: 0.8),
            .init(color: Color(red: 0.80, green: 0.82, blue: 0.86), location: 1.0)
        ])
    }
}
