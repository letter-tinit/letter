import Foundation

public protocol BudgetConfigurationRepository {
    func load(defaultCycleDay: Int) throws -> BudgetConfiguration
    func saveTransactionTemplate(_ plan: BudgetTransactionTemplate) throws
    func deleteTransactionTemplate(_ planID: UUID) throws
    func updateCycleDay(_ day: Int) throws
}
