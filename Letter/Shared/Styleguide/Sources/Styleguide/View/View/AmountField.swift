//
//  AmountField.swift
//  Letter
//
//  Created by Codex on 25/8/26.
//

import SwiftUI
import Domain
import Core
import Utility

/// The app-wide input control for nonfractional Vietnamese đồng amounts.
public struct AmountField: View {
    private static let currencyCode = "VND"
    private static let currencySymbol = "₫"

    private let title: String
    @Binding private var text: String

    @ScaledMetric(relativeTo: .body) private var currencyInset: CGFloat = 24

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    public var body: some View {
        TextField(title, text: $text)
            .keyboardType(.numberPad)
            .padding(.trailing, currencyInset)
            .overlay(alignment: .trailing) {
                Text(Self.currencySymbol)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)
            }
            .accessibilityValue(
                text.isEmpty ? "" : "\(text) \(Self.currencyCode)"
            )
            .onChange(of: text, initial: true) { _, newValue in
                let formattedAmount = CurrencyInputFormatter.format(newValue)

                if formattedAmount != newValue {
                    text = formattedAmount
                }
            }
    }
}
