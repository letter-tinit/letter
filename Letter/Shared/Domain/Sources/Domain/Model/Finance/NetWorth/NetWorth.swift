//
//  NetWorth.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//
//

import Foundation
import Utility

// MARK: - Phân loại (giữ nguyên, không cần đổi để dùng với SwiftData)

/// App-owned classification. Its localized labels live in the presentation layer.
public enum NetWorthCategory: String, CaseIterable, Hashable, Codable {
    case cashAndCashEquivalents
    case receivables
    case tangibleAssets
    case financialAssets
    case shortTermDebt
    case longTermDebt

    public var group: NetWorthGroup {
        switch self {
        case .cashAndCashEquivalents, .receivables, .tangibleAssets, .financialAssets:
            return .assets
        case .shortTermDebt, .longTermDebt:
            return .liabilities
        }
    }
}

public enum NetWorthGroup: String, CaseIterable, Hashable, Codable {
    case assets
    case liabilities
    
    public var categories: [NetWorthCategory] {
        NetWorthCategory.allCases.filter { $0.group == self }
    }
}

public struct NetWorthData {
    public let planItems: [NetWorthPlanItem]
    public let snapshots: [NetWorthSnapshot]
    public init(planItems: [NetWorthPlanItem], snapshots: [NetWorthSnapshot]) { self.planItems = planItems; self.snapshots = snapshots }
}

// MARK: - NetWorthPlanItem

/// A user-configured field reused for later monthly snapshots.
public final class NetWorthPlanItem: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var category: NetWorthCategory = NetWorthCategory.cashAndCashEquivalents
    public var name: String = ""
    public var displayOrder: Int = 0

    /// Mỗi item có 1 giá trị (hoặc để trống) ở mỗi snapshot.
    /// Xoá item -> xoá luôn các giá trị liên quan ở mọi snapshot.
    public var values: [NetWorthValue] = []

    public init(
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

    public static func == (lhs: NetWorthPlanItem, rhs: NetWorthPlanItem) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - NetWorthValue

/// Nil represents a blank cell in the workbook; zero represents an explicitly entered 0.
public final class NetWorthValue: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var amount: Decimal?

    public var planItem: NetWorthPlanItem?

    /// Quan hệ ngược tới snapshot sở hữu giá trị này.
    public var snapshot: NetWorthSnapshot?

    public init(id: UUID = UUID(), amount: Decimal? = nil) {
        self.id = id
        self.amount = amount
    }

    public static func == (lhs: NetWorthValue, rhs: NetWorthValue) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

// MARK: - NetWorthSnapshot

/// One month-end net-worth measurement. It stores only values, not duplicated labels.
public final class NetWorthSnapshot: Identifiable, Hashable {
    public var id: UUID = UUID()
    public var asOfDate: Date = Date()
    public var isLocked: Bool = false

    /// Xoá snapshot -> xoá luôn các giá trị của tháng đó.
    public var values: [NetWorthValue] = []

    public init(id: UUID = UUID(), asOfDate: Date) {
        self.id = id
        self.asOfDate = asOfDate
    }

    public static func == (lhs: NetWorthSnapshot, rhs: NetWorthSnapshot) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    public func amount(for item: NetWorthPlanItem) -> Decimal? {
        values.first(where: { $0.planItem?.id == item.id })?.amount
    }

    public func setAmount(_ amount: Decimal?, for item: NetWorthPlanItem) {
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
    public func total(for group: NetWorthGroup, using items: [NetWorthPlanItem]) -> Decimal {
        items
            .filter { $0.category.group == group }
            .compactMap { amount(for: $0) }
            .reduce(.zero, +)
    }

    public func subtotal(for category: NetWorthCategory, using items: [NetWorthPlanItem]) -> Decimal {
        items
            .filter { $0.category == category }
            .compactMap { amount(for: $0) }
            .reduce(.zero, +)
    }

    public func missingValueCount(using items: [NetWorthPlanItem]) -> Int {
        items.filter { amount(for: $0) == nil }.count
    }

    public func netWorth(using items: [NetWorthPlanItem]) -> Decimal {
        total(for: .assets, using: items) - total(for: .liabilities, using: items)
    }
}
