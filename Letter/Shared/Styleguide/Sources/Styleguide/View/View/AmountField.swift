//
//  AmountField.swift
//  Letter
//
//  Created by Codex on 25/8/26.
//

import SwiftUI
import Domain
import Utility

/// The app-wide input control for nonfractional Vietnamese đồng amounts.
public struct AmountField: View {
    private static let currencyCode = "VND"
    private static let currencySymbol = "₫"

    private let title: String
    @Binding private var text: String

    public init(_ title: String, text: Binding<String>) {
        self.title = title
        _text = text
    }

    public var body: some View {
        HStack(spacing: 6) {
            // Size the editor to its displayed text, while allowing long amounts to shrink.
            Text(text.isEmpty ? title : text)
                .customFont(.body)
                .lineLimit(1)
                .hidden()
                .overlay {
                    TextField(title, text: $text)
                        .customFont(.body)
                        .keyboardType(.numberPad)
                        .accessibilityValue(
                            text.isEmpty ? "" : "\(text) \(Self.currencyCode)"
                        )
                }

            Text(Self.currencySymbol)
                .customFont(.body)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            Spacer(minLength: 0)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .customFont(.body)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("amountField.clear".localized)
            }
        }
        .onChange(of: text, initial: true) { _, newValue in
            let formattedAmount = CurrencyInputFormatter.format(newValue)

            if formattedAmount != newValue {
                text = formattedAmount
            }
        }
    }
}
