import Foundation
import SwiftData
import Domain
import Core
import Utility

@MainActor
public final class ImpNetWorthRepository: NetWorthRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchData() throws -> NetWorthData {
        let itemRecords = try modelContext.fetch(FetchDescriptor<NetWorthPlanItemRecord>(
            sortBy: [SortDescriptor(\.displayOrder)]
        ))
        let items = Dictionary(uniqueKeysWithValues: itemRecords.map { record in
            let item = NetWorthPlanItem(
                id: record.id,
                category: record.category,
                name: record.name,
                displayOrder: record.displayOrder
            )
            return (item.id, item)
        })
        let snapshots = try modelContext.fetch(FetchDescriptor<NetWorthSnapshotRecord>(
            sortBy: [SortDescriptor(\.asOfDate, order: .reverse)]
        )).map { record in
            let snapshot = NetWorthSnapshot(id: record.id, asOfDate: record.asOfDate)
            snapshot.isLocked = record.isLocked
            snapshot.values = record.values.map { valueRecord in
                let value = NetWorthValue(id: valueRecord.id, amount: valueRecord.amount)
                value.snapshot = snapshot
                value.planItem = valueRecord.planItem.flatMap { items[$0.id] }
                value.planItem?.values.append(value)
                return value
            }
            return snapshot
        }
        return NetWorthData(planItems: Array(items.values), snapshots: snapshots)
    }

    public func saveSnapshot(_ snapshot: NetWorthSnapshot) throws {
        if let existing = try snapshotRecord(id: snapshot.id) {
            modelContext.delete(existing)
            try modelContext.save()
        }
        let record = NetWorthSnapshotRecord(
            id: snapshot.id,
            asOfDate: snapshot.asOfDate,
            isLocked: snapshot.isLocked
        )
        record.values = try snapshot.values.map { value in
            let child = NetWorthValueRecord(id: value.id, amount: value.amount)
            child.snapshot = record
            child.planItem = try value.planItem.flatMap { try itemRecord(id: $0.id) }
            return child
        }
        modelContext.insert(record)
        try modelContext.save()
    }

    public func savePlanItem(_ item: NetWorthPlanItem) throws {
        let record = try itemRecord(id: item.id) ?? NetWorthPlanItemRecord(
            id: item.id,
            category: item.category,
            name: item.name,
            displayOrder: item.displayOrder
        )
        record.category = item.category
        record.name = item.name
        record.displayOrder = item.displayOrder
        if record.modelContext == nil { modelContext.insert(record) }
        try modelContext.save()
    }

    public func deletePlanItem(id: UUID) throws {
        if let record = try itemRecord(id: id) { modelContext.delete(record) }
        try modelContext.save()
    }

    public func deleteSnapshot(id: UUID) throws {
        if let record = try snapshotRecord(id: id) { modelContext.delete(record) }
        try modelContext.save()
    }

    private func itemRecord(id: UUID) throws -> NetWorthPlanItemRecord? {
        try modelContext.fetch(FetchDescriptor<NetWorthPlanItemRecord>()).first { $0.id == id }
    }

    private func snapshotRecord(id: UUID) throws -> NetWorthSnapshotRecord? {
        try modelContext.fetch(FetchDescriptor<NetWorthSnapshotRecord>()).first { $0.id == id }
    }
}
