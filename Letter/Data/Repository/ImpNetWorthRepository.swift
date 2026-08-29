import SwiftData

final class ImpNetWorthRepository: NetWorthRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func addSnapshot(_ snapshot: NetWorthSnapshot) throws {
        modelContext.insert(snapshot)
        try save()
    }

    func addPlanItem(_ item: NetWorthPlanItem) throws {
        modelContext.insert(item)
        try save()
    }

    func removePlanItem(_ item: NetWorthPlanItem) throws {
        modelContext.delete(item)
        try save()
    }

    func removeSnapshot(_ snapshot: NetWorthSnapshot) throws {
        modelContext.delete(snapshot)
        try save()
    }

    func save() throws {
        try modelContext.save()
    }
}
