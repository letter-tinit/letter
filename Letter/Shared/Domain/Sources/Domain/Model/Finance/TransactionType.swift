//
//  TransactionType.swift
//  Letter
//
//  Created by TiniT on 24/7/26.
//

public enum TransactionType: String, CaseIterable, Codable {
    case expense, income
    public var icon: String { self == .expense ? "arrow.down" : "arrow.up" }
    public var titleKey: String { "transaction.type.\(rawValue)" }
    public var localizedTitle: String { titleKey.localized }
}
