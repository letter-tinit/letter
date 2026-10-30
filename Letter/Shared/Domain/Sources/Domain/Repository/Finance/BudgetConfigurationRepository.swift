import Foundation

public protocol BudgetConfigurationRepository {
    func load(defaultCycleDay: Int) throws -> BudgetConfiguration
    func saveFixedPlan(_ plan: BudgetFixedPlan, for budgetID: UUID?) throws
    func deleteFixedPlan(_ planID: UUID) throws
    func applyFixedPlan(_ planID: UUID, to budgetID: UUID, on date: Date) throws
    func updateCycleDay(_ day: Int) throws
}
