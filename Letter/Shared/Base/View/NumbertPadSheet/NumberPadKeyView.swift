//
//  NumberPadKeyView.swift
//  Letter
//
//  Created by Tín Nguyễn on 29/8/26.
//

import SwiftUI

struct NumberPadKeyView: View {
    enum KeyType {
        case standard
        case warning
        case problem
        
        var color: Color {
            switch self {
            case .standard:
                    .clear
            case .warning:
                    .peachOrange
            case .problem:
                    .red
            }
        }
    }
    
    let label: String
    var keyType: KeyType = .standard
    let action: () -> Void
    
    init(label: String, action: @escaping () -> Void) {
        self.label = label
        if label.contains("C") {
            keyType = .problem
        }
        
        if label.contains("⌫") {
            keyType = .warning
        }
        
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .customFont(.title2, weight: .medium)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .appGlassEffect(
                    .regular.tint(keyType.color.opacity(0.7)),
                    in: .rect(cornerRadius: 12)
                )
        }
    }
}
