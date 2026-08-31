//
//  NumberPadSheet.swift
//  Letter
//
//  Created by Tín Nguyễn on 29/8/26.
//

import SwiftUI
import Domain
import Utility

public struct NumberPadSheet: View {
    let habitName: String
    let unit: String
    let current: Int
    let goal: Int
    let onConfirm: (Int) -> Void
    public init(habitName: String, unit: String, current: Int, goal: Int, onConfirm: @escaping (Int) -> Void) { self.habitName=habitName; self.unit=unit; self.current=current; self.goal=goal; self.onConfirm=onConfirm }
    
    @Environment(\.dismiss) private var dismiss
    @State private var input: String = ""
    
    private let keys: [[String]] = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["C", "0", "⌫"]
    ]
    
    private var parsedValue: Int { Int(input) ?? 0 }
    
    public var body: some View {
        VStack(alignment: .center, spacing: 16) {
            // Display
            Text(input.isEmpty ? "0" : input)
                .customFont(size: 48, weight: .semibold)
                .contentTransition(.numericText())
                .animation(.snappy, value: input)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .bottomTrailing) {
                    Text(unit)
                        .customFont(.caption)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .appGlassEffect(
                            .regular,
                            in: .rect(cornerRadius: 3)
                        )
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
                let value = parsedValue
                if value > 0 {
                    onConfirm(value)
                }
                dismiss()
            } label: {
                Text("common.done".localized)
                    .customFont(.headline, weight: .semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(.primary)
                    .animation(.snappy, value: parsedValue)
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
            input = ""
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        default:
            // Prevent leading zeros and cap at 4 digits
            if input == "0" { input = "" }
            if input.count < 4 { input += key }
        }
    }
}
