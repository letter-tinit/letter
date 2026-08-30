//
//  NetWorth.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//
//

import Foundation

// MARK: - Phân loại (giữ nguyên, không cần đổi để dùng với SwiftData)

/// App-owned classification. Its localized labels live in the presentation layer.
enum NetWorthCategory: String, CaseIterable, Hashable, Codable {
    case cashAndCashEquivalents
    case receivables
    case tangibleAssets
    case financialAssets
    case shortTermDebt
    case longTermDebt

    var group: NetWorthGroup {
        switch self {
        case .cashAndCashEquivalents, .receivables, .tangibleAssets, .financialAssets:
            return .assets
        case .shortTermDebt, .longTermDebt:
            return .liabilities
        }
    }
}

enum NetWorthGroup: String, CaseIterable, Hashable, Codable {
    case assets
    case liabilities
    
    var categories: [NetWorthCategory] {
        NetWorthCategory.allCases.filter { $0.group == self }
    }
}

struct NetWorthData {
    let planItems: [NetWorthPlanItem]
    let snapshots: [NetWorthSnapshot]
}

// MARK: - NetWorthPlanItem

/// A user-configured field reused for later monthly snapshots.
final class NetWorthPlanItem: Identifiable, Hashable {
    var id: UUID = UUID()
    var category: NetWorthCategory = NetWorthCategory.cashAndCashEquivalents
    var name: String = ""
    var displayOrder: Int = 0

    /// Mỗi item có 1 giá trị (hoặc để trống) ở mỗi snapshot.
    /// Xoá item -> xoá luôn các giá trị liên quan ở mọi snapshot.
    var values: [NetWorthValue] = []

    init(
        id: UUID = UUID(),
        category: NetWorthCategory,
        name: String,
        displayOrder: Int
    ) {
        self.id = id
        self.category = category
        self.name = name
        self.displayOrder = displayOrder
    }

    static func == (lhs: NetWorthPlanItem, rhs: NetWorthPlanItem) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - NetWorthValue

/// Nil represents a blank cell in the workbook; zero represents an explicitly entered 0.
final class NetWorthValue: Identifiable, Hashable {
    var id: UUID = UUID()
    var amount: Decimal?

    var planItem: NetWorthPlanItem?

    /// Quan hệ ngược tới snapshot sở hữu giá trị này.
    var snapshot: NetWorthSnapshot?

    init(id: UUID = UUID(), amount: Decimal? = nil) {
        self.id = id
        self.amount = amount
    }

    static func == (lhs: NetWorthValue, rhs: NetWorthValue) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - NetWorthSnapshot

/// One month-end net-worth measurement. It stores only values, not duplicated labels.
final class NetWorthSnapshot: Identifiable, Hashable {
    var id: UUID = UUID()
    var asOfDate: Date = Date()
    var isLocked: Bool = false

    /// Xoá snapshot -> xoá luôn các giá trị của tháng đó.
    var values: [NetWorthValue] = []

    init(id: UUID = UUID(), asOfDate: Date) {
        self.id = id
        self.asOfDate = asOfDate
    }

    static func == (lhs: NetWorthSnapshot, rhs: NetWorthSnapshot) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    func amount(for item: NetWorthPlanItem) -> Decimal? {
        values.first(where: { $0.planItem?.id == item.id })?.amount
    }

    func setAmount(_ amount: Decimal?, for item: NetWorthPlanItem) {
        if let existing = values.first(where: { $0.planItem?.id == item.id }) {
            existing.amount = amount
        } else {
            let value = NetWorthValue(amount: amount)
            value.planItem = item
            value.snapshot = self
            values.append(value)
        }
    }

    /// Nil is deliberately treated as zero only for the workbook-equivalent subtotal.
    /// The UI can still show it as "chưa cập nhật" via `missingValueCount`.
    func total(for group: NetWorthGroup, using items: [NetWorthPlanItem]) -> Decimal {
        items
            .filter { $0.category.group == group }
            .compactMap { amount(for: $0) }
            .reduce(.zero, +)
    }

    func subtotal(for category: NetWorthCategory, using items: [NetWorthPlanItem]) -> Decimal {
        items
            .filter { $0.category == category }
            .compactMap { amount(for: $0) }
            .reduce(.zero, +)
    }

    func missingValueCount(using items: [NetWorthPlanItem]) -> Int {
        items.filter { amount(for: $0) == nil }.count
    }

    func netWorth(using items: [NetWorthPlanItem]) -> Decimal {
        total(for: .assets, using: items) - total(for: .liabilities, using: items)
    }
}
