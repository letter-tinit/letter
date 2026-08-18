//
//  NetWorth.swift
//  Personal Finance
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

enum NetWorthPlanError: Error {
    case itemNotFound
}

enum NetWorthDataValidationError: Error {
    case invalidSnapshotYear
    case duplicateSnapshotMonth
    case duplicateValue
    case negativeAmount
}

// MARK: - NetWorthPlanItem

/// A user-configured field reused for later monthly snapshots.
@Model
final class NetWorthPlanItem {
    @Attribute(.unique) var id: UUID = UUID()
    var category: NetWorthCategory = NetWorthCategory.cashAndCashEquivalents
    var name: String = ""
    var displayOrder: Int = 0

    /// Quan hệ ngược tới năm sở hữu item này.
    var year: NetWorthYear?

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

    var year: NetWorthYear?

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

// MARK: - NetWorthYear

/// One year's reusable item plan and its monthly measurements.
@Model
final class NetWorthYear {
    var id: UUID = UUID()
    @Attribute(.unique) var year: Int

    @Relationship(deleteRule: .cascade, inverse: \NetWorthPlanItem.year)
    var planItems: [NetWorthPlanItem] = []

    @Relationship(deleteRule: .cascade, inverse: \NetWorthSnapshot.year)
    var snapshots: [NetWorthSnapshot] = []

    init(id: UUID = UUID(), year: Int) {
        self.id = id
        self.year = year
    }

    func items(in category: NetWorthCategory) -> [NetWorthPlanItem] {
        planItems
            .filter { $0.category == category }
            .sorted { $0.displayOrder < $1.displayOrder }
    }

    @discardableResult
    func addItem(category: NetWorthCategory, name: String) -> NetWorthPlanItem {
        let nextDisplayOrder = (items(in: category).map(\.displayOrder).max() ?? 0) + 1
        let item = NetWorthPlanItem(
            category: category,
            name: name,
            displayOrder: nextDisplayOrder
        )
        item.year = self
        planItems.append(item)
        return item
    }

    func updateItem(id: UUID, category: NetWorthCategory, name: String) throws {
        guard let item = planItems.first(where: { $0.id == id }) else {
            throw NetWorthPlanError.itemNotFound
        }

        if item.category != category {
            item.displayOrder = (items(in: category).map(\.displayOrder).max() ?? 0) + 1
        }
        item.category = category
        item.name = name
    }

    func removeItem(id: UUID) throws {
        guard let index = planItems.firstIndex(where: { $0.id == id }) else {
            throw NetWorthPlanError.itemNotFound
        }
        // values liên quan tự xoá theo nhờ deleteRule: .cascade ở NetWorthPlanItem.values
        planItems.remove(at: index)
    }

    func containsSnapshot(in month: Date, calendar: Calendar = .current) -> Bool {
        snapshots.contains { calendar.isDate($0.asOfDate, equalTo: month, toGranularity: .month) }
    }

    @discardableResult
    func addSnapshot(for month: Date, calendar: Calendar = .current) throws -> NetWorthSnapshot {
        let monthStart = calendar.startOfMonth(for: month)
        guard calendar.component(.year, from: monthStart) == year else {
            throw NetWorthDataValidationError.invalidSnapshotYear
        }
        guard !containsSnapshot(in: monthStart, calendar: calendar) else {
            throw NetWorthDataValidationError.duplicateSnapshotMonth
        }

        let snapshot = NetWorthSnapshot(asOfDate: monthStart)
        snapshot.year = self
        snapshots.append(snapshot)
        return snapshot
    }

    func addSnapshotsForAllMonths(calendar: Calendar = .current) throws {
        for month in 1...12 {
            let monthStart = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
            _ = try addSnapshot(for: monthStart, calendar: calendar)
        }
    }

    func validate(calendar: Calendar = .current) throws {
        var snapshotMonths = Set<Date>()

        for snapshot in snapshots {
            guard calendar.component(.year, from: snapshot.asOfDate) == year else {
                throw NetWorthDataValidationError.invalidSnapshotYear
            }

            let monthStart = calendar.startOfMonth(for: snapshot.asOfDate)
            guard snapshotMonths.insert(monthStart).inserted else {
                throw NetWorthDataValidationError.duplicateSnapshotMonth
            }

            var seenItemIDs = Set<UUID>()
            for value in snapshot.values {
                guard let itemID = value.planItem?.id else { continue }
                guard seenItemIDs.insert(itemID).inserted else {
                    throw NetWorthDataValidationError.duplicateValue
                }
                guard value.amount == nil || value.amount! >= .zero else {
                    throw NetWorthDataValidationError.negativeAmount
                }
            }
        }
    }

    /// Tạo năm mới, sao chép danh sách hạng mục (planItems) và seed đủ 12 tháng.
    func reusingPlan(for newYear: Int) -> NetWorthYear {
        let data = NetWorthYear(year: newYear)
        for item in planItems {
            let copy = NetWorthPlanItem(
                category: item.category,
                name: item.name,
                displayOrder: item.displayOrder
            )
            copy.year = data
            data.planItems.append(copy)
        }
        _ = try? data.addSnapshotsForAllMonths()
        return data
    }
}
