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
        return BudgetConfiguration(fixedPlans: plans, cycleDay: settings?.day ?? defaultCycleDay)
    }

    public func saveFixedPlan(_ plan: BudgetFixedPlan, for budgetID: UUID?) throws {
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

        if let budgetID,
           let budget = try findBudget(budgetID),
           !budget.isLocked,
           let transaction = budget.transactions.first(where: { $0.fixedPlanID == plan.id }) {
            transaction.transactionDescription = plan.description
            transaction.amount = plan.amount
            transaction.categoryRawValue = plan.category.rawValue
        }
        try modelContext.save()
    }

    public func deleteFixedPlan(_ planID: UUID) throws {
        if let record = try findPlan(planID) { modelContext.delete(record) }
        try modelContext.save()
    }

    public func applyFixedPlan(_ planID: UUID, to budgetID: UUID, on date: Date) throws {
        guard let budget = try findBudget(budgetID), !budget.isLocked,
              let plan = try findPlan(planID),
              !budget.transactions.contains(where: { $0.fixedPlanID == planID }) else { return }

        let transaction = BudgetTransactionRecord(id: UUID(), amount: plan.amount, description: plan.planDescription,
                                                  date: date, categoryRawValue: plan.categoryRawValue, fixedPlanID: planID)
        transaction.budget = budget
        budget.transactions.append(transaction)
        modelContext.insert(transaction)
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

    private func findBudget(_ id: UUID) throws -> BudgetRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetRecord>(predicate: #Predicate { $0.id == id })).first
    }

    private func findPlan(_ id: UUID) throws -> BudgetFixedPlanRecord? {
        try modelContext.fetch(FetchDescriptor<BudgetFixedPlanRecord>(predicate: #Predicate { $0.id == id })).first
    }
}
