import Foundation

@MainActor
protocol HabitDetailUseCase {
    func load(habitID: UUID) throws -> HabitDetailData?
    func setArchived(_ archived: Bool, habitID: UUID, now: Date) throws
    func delete(habitID: UUID) throws
    func deleteSeries(containing habitID: UUID) throws
}

@MainActor
final class ImpHabitDetailUseCase: HabitDetailUseCase {
    private let repository: any HabitRepository
    private let notifications: any HabitNotificationRepository

    init(
        repository: any HabitRepository,
        notifications: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notifications = notifications
    }

    func load(habitID: UUID) throws -> HabitDetailData? {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            return nil
        }

        let previousVersion = habit.replacedHabitID.flatMap { previousID in
            habits.first { $0.id == previousID }
        }
        let nextVersion = habits
            .filter { $0.replacedHabitID == habit.id }
            .sorted { $0.displayVersionNumber < $1.displayVersionNumber }
            .first
        let seriesCount = habits.filter {
            $0.effectiveSeriesID == habit.effectiveSeriesID
        }.count

        return HabitDetailData(
            habit: habit,
            previousVersionNumber: previousVersion?.displayVersionNumber,
            nextVersionNumber: nextVersion?.displayVersionNumber,
            seriesHabitCount: seriesCount
        )
    }

    func setArchived(_ archived: Bool, habitID: UUID, now: Date) throws {
        guard let source = try snapshot(id: habitID) else {
            throw HabitDetailError.habitNotFound
        }
        guard (source.archivedAt != nil) != archived else { return }

        if archived {
            notifications.cancelNotifications(for: source)
        }

        do {
            guard let updated = try repository.setHabitArchived(
                archived,
                id: habitID,
                at: now
            ) else {
                if archived { notifications.rescheduleNotifications(for: source) }
                throw HabitDetailError.habitNotFound
            }
            if !archived {
                notifications.rescheduleNotifications(for: updated)
            }
        } catch let error as HabitDetailError {
            throw error
        } catch {
            if archived {
                notifications.rescheduleNotifications(for: source)
            }
            throw HabitDetailError.persistenceFailed(error)
        }
    }

    func delete(habitID: UUID) throws {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        notifications.cancelNotifications(for: habit)
        do {
            guard try repository.deleteHabit(
                id: habitID,
                reconnectingTo: habit.replacedHabitID
            ) else {
                restoreNotification(for: habit)
                throw HabitDetailError.habitNotFound
            }
        } catch let error as HabitDetailError {
            throw error
        } catch {
            restoreNotification(for: habit)
            throw HabitDetailError.persistenceFailed(error)
        }
    }

    func deleteSeries(containing habitID: UUID) throws {
        let habits = try repository.fetchHabitSnapshots()
        guard let habit = habits.first(where: { $0.id == habitID }) else {
            throw HabitDetailError.habitNotFound
        }

        let series = habits.filter {
            $0.effectiveSeriesID == habit.effectiveSeriesID
        }
        series.forEach(notifications.cancelNotifications)
        do {
            try repository.deleteHabits(ids: Set(series.map(\.id)))
        } catch {
            series.forEach(restoreNotification)
            throw HabitDetailError.persistenceFailed(error)
        }
    }
}

private extension ImpHabitDetailUseCase {
    func snapshot(id: UUID) throws -> HabitSnapshot? {
        try repository.fetchHabitSnapshots().first { $0.id == id }
    }

    func restoreNotification(for habit: HabitSnapshot) {
        guard habit.archivedAt == nil else { return }
        notifications.rescheduleNotifications(for: habit)
    }
}
