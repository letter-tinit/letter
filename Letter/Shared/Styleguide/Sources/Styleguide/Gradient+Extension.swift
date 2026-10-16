//
//  Gradient+Extension.swift
//  Letter
//
//  Created by TiniT on 7/8/26.
//


//
//  Gradient+Extension.swift
//  Letter
//

import SwiftUI
import UIKit
import Domain
import Utility

// MARK: - Adaptive Color

//public extension Color {
//    static func adaptive(
//        light: UIColor,
//        dark: UIColor
//    ) -> Color {
//        let dynamicColor = UIColor { traits in
//            if traits.userInterfaceStyle == .dark {
//                return dark
//            } else {
//                return light
//            }
//        }
//
//        return Color(uiColor: dynamicColor)
//    }
//}

// MARK: - Glass Gradients

public extension Gradient {
    enum Glass {

        // MARK: Rose

        public static let rose = makeGradient(
            light: [
                UIColor(red: 1.00, green: 0.95, blue: 0.97, alpha: 1),
                UIColor(red: 1.00, green: 0.86, blue: 0.91, alpha: 1),
                UIColor(red: 0.96, green: 0.76, blue: 0.85, alpha: 1),
                UIColor(red: 1.00, green: 0.90, blue: 0.94, alpha: 1),
                UIColor(red: 0.97, green: 0.82, blue: 0.89, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.30, green: 0.16, blue: 0.21, alpha: 1),
                UIColor(red: 0.40, green: 0.21, blue: 0.28, alpha: 1),
                UIColor(red: 0.48, green: 0.27, blue: 0.35, alpha: 1),
                UIColor(red: 0.34, green: 0.18, blue: 0.25, alpha: 1),
                UIColor(red: 0.42, green: 0.23, blue: 0.31, alpha: 1)
            ]
        )

        // MARK: Blue

        public static let blue = makeGradient(
            light: [
                UIColor(red: 0.95, green: 0.98, blue: 1.00, alpha: 1),
                UIColor(red: 0.84, green: 0.92, blue: 1.00, alpha: 1),
                UIColor(red: 0.70, green: 0.84, blue: 0.98, alpha: 1),
                UIColor(red: 0.90, green: 0.96, blue: 1.00, alpha: 1),
                UIColor(red: 0.80, green: 0.90, blue: 0.99, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.09, green: 0.16, blue: 0.23, alpha: 1),
                UIColor(red: 0.14, green: 0.24, blue: 0.33, alpha: 1),
                UIColor(red: 0.20, green: 0.33, blue: 0.46, alpha: 1),
                UIColor(red: 0.12, green: 0.20, blue: 0.28, alpha: 1),
                UIColor(red: 0.16, green: 0.28, blue: 0.38, alpha: 1)
            ]
        )

        // MARK: Mint

        public static let mint = makeGradient(
            light: [
                UIColor(red: 0.95, green: 1.00, blue: 0.98, alpha: 1),
                UIColor(red: 0.82, green: 0.96, blue: 0.90, alpha: 1),
                UIColor(red: 0.68, green: 0.90, blue: 0.80, alpha: 1),
                UIColor(red: 0.90, green: 0.99, blue: 0.94, alpha: 1),
                UIColor(red: 0.78, green: 0.93, blue: 0.86, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.10, green: 0.20, blue: 0.17, alpha: 1),
                UIColor(red: 0.14, green: 0.28, blue: 0.23, alpha: 1),
                UIColor(red: 0.18, green: 0.36, blue: 0.29, alpha: 1),
                UIColor(red: 0.11, green: 0.24, blue: 0.19, alpha: 1),
                UIColor(red: 0.16, green: 0.31, blue: 0.25, alpha: 1)
            ]
        )

        // MARK: Lavender

        public static let lavender = makeGradient(
            light: [
                UIColor(red: 0.98, green: 0.96, blue: 1.00, alpha: 1),
                UIColor(red: 0.91, green: 0.84, blue: 0.98, alpha: 1),
                UIColor(red: 0.80, green: 0.70, blue: 0.92, alpha: 1),
                UIColor(red: 0.95, green: 0.90, blue: 1.00, alpha: 1),
                UIColor(red: 0.86, green: 0.78, blue: 0.96, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.19, green: 0.14, blue: 0.25, alpha: 1),
                UIColor(red: 0.29, green: 0.20, blue: 0.33, alpha: 1),
                UIColor(red: 0.35, green: 0.25, blue: 0.42, alpha: 1),
                UIColor(red: 0.22, green: 0.17, blue: 0.29, alpha: 1),
                UIColor(red: 0.29, green: 0.20, blue: 0.34, alpha: 1)
            ]
        )

        // MARK: Beige

        public static let beige = makeGradient(
            light: [
                UIColor(red: 1.00, green: 0.98, blue: 0.94, alpha: 1),
                UIColor(red: 0.96, green: 0.90, blue: 0.80, alpha: 1),
                UIColor(red: 0.88, green: 0.78, blue: 0.64, alpha: 1),
                UIColor(red: 1.00, green: 0.94, blue: 0.86, alpha: 1),
                UIColor(red: 0.92, green: 0.84, blue: 0.72, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.20, green: 0.18, blue: 0.14, alpha: 1),
                UIColor(red: 0.27, green: 0.22, blue: 0.15, alpha: 1),
                UIColor(red: 0.36, green: 0.29, blue: 0.21, alpha: 1),
                UIColor(red: 0.22, green: 0.19, blue: 0.15, alpha: 1),
                UIColor(red: 0.30, green: 0.25, blue: 0.18, alpha: 1)
            ]
        )

        // MARK: Golden

        public static let golden = makeGradient(
            light: [
                UIColor(red: 1.00, green: 0.97, blue: 0.82, alpha: 1),
                UIColor(red: 0.97, green: 0.85, blue: 0.50, alpha: 1),
                UIColor(red: 0.92, green: 0.76, blue: 0.32, alpha: 1),
                UIColor(red: 1.00, green: 0.92, blue: 0.62, alpha: 1),
                UIColor(red: 0.94, green: 0.79, blue: 0.40, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.21, green: 0.17, blue: 0.09, alpha: 1),
                UIColor(red: 0.29, green: 0.23, blue: 0.11, alpha: 1),
                UIColor(red: 0.40, green: 0.31, blue: 0.14, alpha: 1),
                UIColor(red: 0.25, green: 0.20, blue: 0.10, alpha: 1),
                UIColor(red: 0.35, green: 0.27, blue: 0.12, alpha: 1)
            ]
        )

        // MARK: Silver

        public static let silver = makeGradient(
            light: [
                UIColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 1),
                UIColor(red: 0.86, green: 0.87, blue: 0.90, alpha: 1),
                UIColor(red: 0.72, green: 0.74, blue: 0.78, alpha: 1),
                UIColor(red: 0.94, green: 0.95, blue: 0.97, alpha: 1),
                UIColor(red: 0.80, green: 0.82, blue: 0.86, alpha: 1)
            ],
            dark: [
                UIColor(red: 0.15, green: 0.16, blue: 0.18, alpha: 1),
                UIColor(red: 0.20, green: 0.21, blue: 0.24, alpha: 1),
                UIColor(red: 0.26, green: 0.28, blue: 0.31, alpha: 1),
                UIColor(red: 0.17, green: 0.18, blue: 0.20, alpha: 1),
                UIColor(red: 0.22, green: 0.24, blue: 0.27, alpha: 1)
            ]
        )

        // MARK: Private Factory

        private static func makeGradient(
            light: [UIColor],
            dark: [UIColor]
        ) -> Gradient {
            precondition(
                light.count == 5 && dark.count == 5,
                "Glass gradients must contain exactly five color stops."
            )

            let locations: [CGFloat] = [
                0.0, 0.35, 0.55, 0.8, 1.0
            ]

            let stops = locations.indices.map { index in
                Gradient.Stop(
                    color: Color.adaptive(
                        light: light[index],
                        dark: dark[index]
                    ),
                    location: locations[index]
                )
            }

            return Gradient(stops: stops)
        }
    }
}
