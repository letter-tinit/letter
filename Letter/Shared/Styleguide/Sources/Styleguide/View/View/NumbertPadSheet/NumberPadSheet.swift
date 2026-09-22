//
//  NumberPadSheet.swift
//  Letter
//
//  Created by Tín Nguyễn on 29/8/26.
//

import SwiftUI
import Utility

public struct NumberPadSheetModel {
    public var unit: String?
    public var input: String
    public var submittedValue: Int?

    public init(
        unit: String? = nil,
        input: String = "",
        submittedValue: Int? = nil
    ) {
        self.unit = unit
        self.input = input
        self.submittedValue = submittedValue
    }

    var parsedValue: Int { Int(input) ?? 0 }
}

public struct NumberPadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding private var model: NumberPadSheetModel

    public init(model: Binding<NumberPadSheetModel>) {
        _model = model
    }
    
    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]

    public var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Display
            Text(model.input.isEmpty ? "0" : model.input)
                .customFont(size: 48, weight: .semibold)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.input)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    if let unit = model.unit {
                        Text(unit)
                            .customFont(.caption)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .appGlassEffect(
                                .regular,
                                in: .rect(cornerRadius: 3)
                            )
                    }
                }
            
            // Number Pad Grid
            VStack(spacing: 10) {
                ForEach(keys, id: \.self) { row in
                    HStack(spacing: 10) {
                        ForEach(row, id: \.self) { key in
                            NumberPadKeyView(label: key) {
                                handleKey(key)
                            }
                        }
                    }
                }
            }
            
            // Confirm Button
            Button {
                let value = model.parsedValue
                if value > 0 {
                    model.submittedValue = value
                    Haptic.impact()
                }
                dismiss()
            } label: {
                Text("common.done".localized)
                    .customFont(.headline, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.primary)
                    .animation(.snappy, value: model.parsedValue)
            }
            .appGlassEffect(
                .regular.interactive(),
                in: .rect(cornerRadius: 14)
            )
            .padding(.horizontal, 4)
            .padding(.bottom, 8)
        }
        .padding(.horizontal, 20)
    }
    
    private func handleKey(_ key: String) {
        switch key {
        case "C":
            model.input = ""
        case "⌫":
            if !model.input.isEmpty { model.input.removeLast() }
        default:
            // Prevent leading zeros and cap at 4 digits
            if model.input == "0" { model.input = "" }
            if model.input.count < 4 { model.input += key }
        }
    }
}
