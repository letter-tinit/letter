//
//  SymbolPickerSheetView.swift
//  Letter
//

import SwiftUI
import Utility

public struct SymbolPickerSheetView: View {
    @Binding private var selectedSymbol: String
    private let symbols: [String]
    private let title: String
    @Environment(\.dismiss) private var dismiss

    private let columns = [
        GridItem(.adaptive(minimum: 52), spacing: 12)
    ]

    public init(
        selectedSymbol: Binding<String>,
        symbols: [String],
        title: String
    ) {
        _selectedSymbol = selectedSymbol
        self.symbols = symbols
        self.title = title
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .customFont(.headline)

            AppScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(symbols, id: \.self) { symbol in
                        Button {
                            selectedSymbol = symbol
                            dismiss()
                        } label: {
                            Image(module: symbol)
                                .customFont(.title3)
                                .padding(8)
                                .scaledToFit()
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .foregroundStyle(selectedSymbol == symbol ? .white : .primary)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedSymbol == symbol ? Color.cyan : Color.primary.opacity(0.06))
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .padding(20)
    }
}
