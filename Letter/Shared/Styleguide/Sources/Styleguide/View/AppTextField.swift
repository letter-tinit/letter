//
//  AppTextField.swift
//  Styleguide
//
//  Created by Tín Nguyễn on 23/10/26.
//

import SwiftUI

public struct AppTextField: View {
    @Binding private var text: String
    @Binding private var isEdited: Bool
    
    private let placeholder: String
    private let maxLength: Int?
    private let maxLines: Int?
    private let showsCharacterCount: Bool
    private let showsClearButton: Bool
    private let axis: Axis
    
    public init(
        _ placeholder: String,
        text: Binding<String>,
        isEdited: Binding<Bool> = .constant(false),
        maxLength: Int? = nil,
        maxLines: Int? = nil,
        showsCharacterCount: Bool = true,
        showsClearButton: Bool = true,
        axis: Axis = .vertical
    ) {
        self.placeholder = placeholder
        self._text = text
        self._isEdited = isEdited
        self.maxLength = maxLength.map { max(0, $0) }
        self.maxLines = maxLines.map { max(1, $0) }
        self.showsCharacterCount = showsCharacterCount
        self.showsClearButton = showsClearButton
        self.axis = axis
    }
    
    private var lineLimit: ClosedRange<Int> {
        guard axis == .vertical else {
            return 1...1
        }
        
        return 1...(maxLines ?? 5)
    }
    
    public var body: some View {
        VStack {
            TextField(
                placeholder,
                text: Binding(
                    get: { text },
                    set: { newValue in
                        updateText(newValue, markAsEdited: true)
                    }
                ),
                axis: axis
            )
            .lineLimit(lineLimit)
            .overlay(alignment: .topTrailing) {
                if showsClearButton && !text.isEmpty {
                    Button {
                        updateText("", markAsEdited: true)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let maxLength, showsCharacterCount {
                Text("\(text.count)/\(maxLength)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func updateText(_ newValue: String, markAsEdited: Bool) {
        var updatedValue = newValue

        if let maxLength {
            updatedValue = String(updatedValue.prefix(maxLength))
        }

        if let maxLines {
            let lines = updatedValue.components(separatedBy: .newlines)

            if lines.count > maxLines {
                updatedValue = lines.prefix(maxLines).joined(separator: "\n")
            }
        }

        guard updatedValue != text else { return }

        text = updatedValue

        if markAsEdited {
            isEdited = true
        }
    }
}
