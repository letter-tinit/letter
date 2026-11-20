import Foundation

public protocol BudgetConfigurationUseCase {
    func load(defaultCycleDay: Int) throws -> BudgetConfiguration
    func save(_ plan: BudgetTransactionTemplate) throws
    func delete(_ planID: UUID) throws
    func setCycleDay(_ day: Int) throws
}

public final class ImpBudgetConfigurationUseCase: BudgetConfigurationUseCase {
    private let repository: any BudgetConfigurationRepository

    public init(repository: any BudgetConfigurationRepository) {
        self.repository = repository
    }

    public func load(defaultCycleDay: Int) throws -> BudgetConfiguration {
        try repository.load(defaultCycleDay: defaultCycleDay)
    }
    public func save(_ plan: BudgetTransactionTemplate) throws {
        try repository.saveTransactionTemplate(plan)
    }
    public func delete(_ planID: UUID) throws { try repository.deleteTransactionTemplate(planID) }
    public func setCycleDay(_ day: Int) throws { try repository.updateCycleDay(day) }
}
