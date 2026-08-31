import Foundation
import Observation
import Domain
import Core
import Utility
import Styleguide

public enum HabitDetailSheet: Hashable, Identifiable {
    case edit
    case newVersion

    public var id: Self { self }
}

@Observable
@MainActor
public final class HabitDetailViewModel {
    private let useCase: any HabitDetailUseCase

    public let habitID: UUID
    public var title = "common.detail".localized
    public var activeSheet: HabitDetailSheet?
    public var showsArchiveConfirmation = false
    public var showsDeleteConfirmation = false
    private(set) var habit: HabitSnapshot?
    private(set) var previousVersionNumber: Int?
    private(set) var nextVersionNumber: Int?
    private(set) var seriesHabitCount = 0
    private(set) var errorMessage: String?

    public var name: String { habit?.name ?? "" }
    public var habitDescription: String { habit?.habitDescription ?? "" }
    public var icon: String { habit?.icon ?? "star.fill" }
    public var colorHex: String { habit?.colorHex ?? AppConstant.defaultColor }
    public var currentStreak: Int { habit?.currentStreak ?? 0 }
    public var longestStreak: Int { habit?.longestStreak ?? 0 }
    public var archivedAt: Date? { habit?.archivedAt }
    public var displayVersionNumber: Int { habit?.displayVersionNumber ?? 1 }
    public var isArchived: Bool { habit?.archivedAt != nil }
    public var canDeleteSeries: Bool { seriesHabitCount > 1 }

    public var shouldShowVersionInfo: Bool {
        habit?.isVersioned == true ||
            previousVersionNumber != nil ||
            nextVersionNumber != nil
    }

    public var repeatTitle: String {
        switch habit?.frequency {
        case .daily: "habit.repeat.daily".localized
        case .weekday: "habit.repeat.weekdays".localized
        case .weekend: "habit.repeat.weekends".localized
        case .custom: "habit.repeat.custom".localized
        case nil: "habit.common.none".localized
        }
    }

    public var goalTitle: String {
        guard let habit else { return "habit.common.none".localized }
        return habit.goalType == .todo
            ? "habit.goal.completeOnce".localized
            : "\(habit.goalCount) \(habit.goalUnit)"
    }

    public var reminderTitle: String {
        let times = habit?.reminders
            .filter(\.isEnabled)
            .map(\.time)
            .sorted() ?? []
        guard !times.isEmpty else { return "habit.common.none".localized }
        return times
            .map { $0.toString(withFormat: .custom("HH:mm")) }
            .joined(separator: ", ")
    }

    public var deleteConfirmationTitle: String {
        (canDeleteSeries
            ? "habit.delete.version.confirmation"
            : "habit.delete.confirmation").localized
    }

    public var deleteConfirmationMessage: String {
        (canDeleteSeries
            ? "habit.delete.version.description"
            : "habit.delete.description").localized
    }

    public init(habitID: UUID, useCase: any HabitDetailUseCase) {
        self.habitID = habitID
        self.useCase = useCase
    }

    public func load() {
        do {
            guard let data = try useCase.load(habitID: habitID) else {
                habit = nil
                return
            }
            habit = data.habit
            previousVersionNumber = data.previousVersionNumber
            nextVersionNumber = data.nextVersionNumber
            seriesHabitCount = data.seriesHabitCount
            errorMessage = nil
        } catch {
            Logger.error("Failed to load Habit detail: \(error)")
            errorMessage = error.localizedDescription
            habit = nil
        }
    }

    public func toggleArchive() -> Bool {
        do {
            try useCase.setArchived(!isArchived, habitID: habitID, now: Date())
            load()
            return true
        } catch {
            Logger.error("Failed to change Habit archive state: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    public func delete() -> Bool {
        performDelete { try useCase.delete(habitID: habitID) }
    }

    public func deleteSeries() -> Bool {
        performDelete { try useCase.deleteSeries(containing: habitID) }
    }

    private func performDelete(_ operation: () throws -> Void) -> Bool {
        do {
            try operation()
            errorMessage = nil
            return true
        } catch {
            Logger.error("Failed to delete Habit: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
}
