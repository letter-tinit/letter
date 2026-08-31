import Foundation

@MainActor
final class HabitBackupPersistence {
    private let repository: ImpHabitRepository
    private let notificationRepository: any HabitNotificationRepository

    init(
        repository: ImpHabitRepository,
        notificationRepository: any HabitNotificationRepository
    ) {
        self.repository = repository
        self.notificationRepository = notificationRepository
    }

    func exportBackup() throws -> HabitBackup {
        let backup = HabitBackup(
            profile: try repository.fetchUserProfileRecord(),
            habits: try repository.fetchHabits()
        )
        try backup.validate()
        return backup
    }

    func importBackup(_ backup: HabitBackup) throws {
        try backup.validate()
        do {
            for habit in try repository.fetchHabitSnapshots() {
                notificationRepository.cancelNotifications(for: habit)
            }
            try repository.removeAllHabitData()
            restoreProfile(from: backup.profile)
            restoreHabits(from: backup.habits)
            try repository.save()
        } catch {
            repository.rollback()
            throw error
        }
    }

    func clearAllData() throws {
        for habit in try repository.fetchHabitSnapshots() {
            notificationRepository.cancelNotifications(for: habit)
        }
        try repository.removeAllHabitData()
        try repository.save()
    }

    private func restoreProfile(from backup: UserProfileBackup?) {
        let profile = UserProfile(displayName: backup?.displayName ?? "habit.profile.defaultName".localized)
        if let backup {
            profile.id = backup.id
            profile.avatarOriginalData = backup.avatarOriginalData
            profile.avatarData = backup.avatarData
            profile.weekStartsOnMonday = backup.weekStartsOnMonday
            profile.usesSimplifiedStatisticsMode = backup.usesSimplifiedStatisticsMode
            profile.defaultReminderTime = backup.defaultReminderTime
            profile.colorScheme = backup.colorScheme
            profile.themeColorHex = backup.themeColorHex
            profile.totalCompletions = backup.totalCompletions
            profile.totalHabitsCreated = backup.totalHabitsCreated
            profile.longestOverallStreak = backup.longestOverallStreak
            profile.joinedAt = backup.joinedAt
        }
        repository.addProfile(profile)
    }

    private func restoreHabits(from backups: [HabitBackupItem]) {
        for backup in backups {
            let habit = Habit(
                name: backup.name,
                description: backup.habitDescription,
                icon: backup.icon,
                colorHex: backup.colorHex,
                startDate: backup.startDate,
                endDate: backup.endDate,
                frequency: backup.frequency,
                targetDaysOfWeek: backup.targetDaysOfWeek,
                goalType: backup.goalType,
                goalCount: backup.goalCount,
                goalUnit: backup.goalUnit,
                seriesID: backup.seriesID ?? backup.id,
                replacedHabitID: backup.replacedHabitID,
                versionNumber: backup.versionNumber ?? 1
            )
            habit.id = backup.id
            habit.createdAt = backup.createdAt
            habit.archivedAt = backup.archivedAt
            habit.sortOrder = backup.sortOrder
            habit.reminderTime = backup.reminderTime
            habit.currentStreak = backup.currentStreak
            habit.longestStreak = backup.longestStreak
            habit.lastCompletedDate = backup.lastCompletedDate

            restoreEntries(backup.entries, into: habit)
            restoreReminders(backup.reminders, into: habit)
            repository.addHabit(habit)
        }
    }

    private func restoreEntries(_ backups: [HabitEntryBackupItem], into habit: Habit) {
        for backup in backups {
            let entry = HabitEntry(
                date: backup.date,
                completedCount: backup.completedCount,
                status: backup.status,
                note: backup.note
            )
            entry.id = backup.id
            entry.mood = backup.mood
            entry.createdAt = backup.createdAt
            entry.updatedAt = backup.updatedAt
            entry.habit = habit
            habit.entries.append(entry)
            repository.addEntry(entry)
        }
    }

    private func restoreReminders(_ backups: [HabitReminderBackupItem], into habit: Habit) {
        for backup in backups {
            let reminder = HabitReminder(
                time: backup.time,
                daysOfWeek: backup.daysOfWeek,
                isEnabled: backup.isEnabled
            )
            reminder.id = backup.id
            reminder.notificationID = backup.notificationID
            reminder.habit = habit
            habit.reminders.append(reminder)
            repository.addReminder(reminder)
        }
    }
}
