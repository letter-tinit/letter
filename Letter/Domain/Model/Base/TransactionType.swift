//
//  TransactionType.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

enum TransactionType: String, CaseIterable, Codable {
    case expense, income
    var icon: String { self == .expense ? "arrow.down" : "arrow.up" }
    var titleKey: String { "transaction.type.\(rawValue)" }
    var localizedTitle: String { titleKey.localized }
}
