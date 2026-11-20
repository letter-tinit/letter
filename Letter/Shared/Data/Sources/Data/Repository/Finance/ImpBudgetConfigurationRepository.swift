import Domain
import Foundation
import SwiftData

public final class ImpBudgetConfigurationRepository: BudgetConfigurationRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func load(defaultCycleDay: Int) throws -> BudgetConfiguration {
        let plans = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(sortBy: [SortDescriptor(\.planDescription)]))
            .map { $0.toDomain() }
        let settings = try modelContext.fetch(FetchDescriptor<BudgetCycleSettingsRecord>(predicate: #Predicate { $0.id == "global" })).first
        return BudgetConfiguration(transactionTemplates: plans, cycleDay: settings?.day ?? defaultCycleDay)
    }

    public func saveTransactionTemplate(_ plan: BudgetTransactionTemplate) throws {
        let planID = plan.id
        let record: BudgetFixedPlanRecord
        if let existing = try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == planID })).first {
            record = existing
            record.planDescription = plan.description
            record.amount = plan.amount
            record.categoryRawValue = plan.category.rawValue
        } else {
            record = BudgetFixedPlanRecord(id: plan.id, description: plan.description, amount: plan.amount,
                                           categoryRawValue: plan.category.rawValue)
            modelContext.insert(record)
        }
        try modelContext.save()
    }

    public func deleteTransactionTemplate(_ planID: UUID) throws {
        if let record = try findPlan(planID) { modelContext.delete(record) }
        try modelContext.save()
    }

    public func updateCycleDay(_ day: Int) throws {
        let normalizedDay = min(28, max(1, day))
        if let settings = try modelContext.fetch(FetchDescriptor<BudgetCycleSettingsRecord>(predicate: #Predicate { $0.id == "global" })).first {
            settings.day = normalizedDay
        } else {
            modelContext.insert(BudgetCycleSettingsRecord(day: normalizedDay))
        }
        try modelContext.save()
    }

    private func findPlan(_ id: UUID) throws -> BudgetFixedPlanRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
