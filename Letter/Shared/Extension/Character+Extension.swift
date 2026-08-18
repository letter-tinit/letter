//
//  Character+Extension.swift
//  Habit
//
//  Created by TiniT on 28/4/26.
//

extension Character {
    var isEmoji: Bool {
        guard let scalar = unicodeScalars.first else { return false }
        return scalar.properties.isEmoji && scalar.value > 0x238C
    }
}
