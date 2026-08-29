import Foundation
import Observation

enum HabitDetailSheet: Hashable, Identifiable {
    case edit
    case newVersion

    var id: Self { self }
}

@Observable
@MainActor
final class HabitDetailViewModel {
    private let useCase: any HabitDetailHandling

    let habitID: UUID
    var title = "common.detail".localized
    var activeSheet: HabitDetailSheet?
    var showsArchiveConfirmation = false
    var showsDeleteConfirmation = false
    private(set) var habit: HabitSnapshot?
    private(set) var previousVersionNumber: Int?
    private(set) var nextVersionNumber: Int?
    private(set) var seriesHabitCount = 0
    private(set) var errorMessage: String?

    var name: String { habit?.name ?? "" }
    var habitDescription: String { habit?.habitDescription ?? "" }
    var icon: String { habit?.icon ?? "star.fill" }
    var colorHex: String { habit?.colorHex ?? AppConstant.defaultColor }
    var currentStreak: Int { habit?.currentStreak ?? 0 }
    var longestStreak: Int { habit?.longestStreak ?? 0 }
    var archivedAt: Date? { habit?.archivedAt }
    var displayVersionNumber: Int { habit?.displayVersionNumber ?? 1 }
    var isArchived: Bool { habit?.archivedAt != nil }
    var canDeleteSeries: Bool { seriesHabitCount > 1 }

    var shouldShowVersionInfo: Bool {
        habit?.isVersioned == true ||
            previousVersionNumber != nil ||
            nextVersionNumber != nil
    }

    var repeatTitle: String {
        switch habit?.frequency {
        case .daily: "habit.repeat.daily".localized
        case .weekday: "habit.repeat.weekdays".localized
        case .weekend: "habit.repeat.weekends".localized
        case .custom: "habit.repeat.custom".localized
        case nil: "habit.common.none".localized
        }
    }

    var goalTitle: String {
        guard let habit else { return "habit.common.none".localized }
        return habit.goalType == .todo
            ? "habit.goal.completeOnce".localized
            : "\(habit.goalCount) \(habit.goalUnit)"
    }

    var reminderTitle: String {
        let times = habit?.reminders
            .filter(\.isEnabled)
            .map(\.time)
            .sorted() ?? []
        guard !times.isEmpty else { return "habit.common.none".localized }
        return times
            .map { $0.toString(withFormat: .custom("HH:mm")) }
            .joined(separator: ", ")
    }

    var deleteConfirmationTitle: String {
        (canDeleteSeries
            ? "habit.delete.version.confirmation"
            : "habit.delete.confirmation").localized
    }

    var deleteConfirmationMessage: String {
        (canDeleteSeries
            ? "habit.delete.version.description"
            : "habit.delete.description").localized
    }

    init(habitID: UUID, useCase: any HabitDetailHandling) {
        self.habitID = habitID
        self.useCase = useCase
    }

    func load() {
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

    func toggleArchive() -> Bool {
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

    func delete() -> Bool {
        performDelete { try useCase.delete(habitID: habitID) }
    }

    func deleteSeries() -> Bool {
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
