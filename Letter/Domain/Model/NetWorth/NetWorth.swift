//
//  NetWorth.swift
//  Letter
//
//  Created by TiniT on 15/7/26.
//
//

import Foundation
import SwiftData

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

// MARK: - NetWorthPlanItem

/// A user-configured field reused for later monthly snapshots.
@Model
final class NetWorthPlanItem {
    @Attribute(.unique) var id: UUID = UUID()
    var category: NetWorthCategory = NetWorthCategory.cashAndCashEquivalents
    var name: String = ""
    var displayOrder: Int = 0

    /// Mỗi item có 1 giá trị (hoặc để trống) ở mỗi snapshot.
    /// Xoá item -> xoá luôn các giá trị liên quan ở mọi snapshot.
    @Relationship(deleteRule: .cascade, inverse: \NetWorthValue.planItem)
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
}

// MARK: - NetWorthValue

/// Nil represents a blank cell in the workbook; zero represents an explicitly entered 0.
@Model
final class NetWorthValue {
    @Attribute(.unique) var id: UUID = UUID()
    var amount: Decimal?

    var planItem: NetWorthPlanItem?

    /// Quan hệ ngược tới snapshot sở hữu giá trị này.
    var snapshot: NetWorthSnapshot?

    init(id: UUID = UUID(), amount: Decimal? = nil) {
        self.id = id
        self.amount = amount
    }
}

// MARK: - NetWorthSnapshot

/// One month-end net-worth measurement. It stores only values, not duplicated labels.
@Model
final class NetWorthSnapshot {
    @Attribute(.unique) var id: UUID = UUID()
    var asOfDate: Date = Date()

    /// Xoá snapshot -> xoá luôn các giá trị của tháng đó.
    @Relationship(deleteRule: .cascade, inverse: \NetWorthValue.snapshot)
    var values: [NetWorthValue] = []

    init(id: UUID = UUID(), asOfDate: Date) {
        self.id = id
        self.asOfDate = asOfDate
    }

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

extension NetWorthSnapshot {
    func isGhoshSnapshot() -> Bool {
        return values.isEmpty || values.filter({ $0.amount != .zero }).isEmpty
    }
    
    var displayName: String {
        var name = asOfDate.toString(withFormat: .month)

        if isGhoshSnapshot() {
            name += " (" + "common.empty".localized + ")"
        }

        return name
    }
}
