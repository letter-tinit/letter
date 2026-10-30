import Foundation

public protocol BudgetConfigurationUseCase {
    func load(defaultCycleDay: Int) throws -> BudgetConfiguration
    func save(_ plan: BudgetFixedPlan, for budgetID: UUID?) throws
    func delete(_ planID: UUID) throws
    func apply(_ planID: UUID, to budgetID: UUID, on date: Date) throws
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
    public func save(_ plan: BudgetFixedPlan, for budgetID: UUID?) throws {
        try repository.saveFixedPlan(plan, for: budgetID)
    }
    public func delete(_ planID: UUID) throws { try repository.deleteFixedPlan(planID) }
    public func apply(_ planID: UUID, to budgetID: UUID, on date: Date) throws {
        try repository.applyFixedPlan(planID, to: budgetID, on: date)
    }
    public func setCycleDay(_ day: Int) throws { try repository.updateCycleDay(day) }
}
