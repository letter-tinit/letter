//
//  HabitViewModel.swift
//  Letter
//
//  Created by TiniT on 28/4/26.
//

import Observation
import Foundation
import SwiftData

@Observable
final class HabitViewModel {
    // MARK: - Dependencies
    private let repository: any HabitRepository
    private let homeQuery: any HabitHomeQuerying
    private let habitEntryMutationPolicy = HabitEntryMutationPolicy()
    private let habitStreakCalculator = HabitStreakCalculator()
    private let notificationScheduler: any HabitNotificationScheduling
    
    var homeTitle: String = AppString.Home.today
    var profileTitle: String = AppString.ScreenTitle.profile
    var habits: [Habit] = []
    @ObservationIgnored private var filteredHabitCache: (
        date: Date,
        today: Date,
        revision: Int,
        items: [HabitListItem]
    )?
    @ObservationIgnored private var dataRevision = 0
    
    var filteredHabit: [HabitListItem] {
        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)
        let today = calendar.startOfDay(for: Date())
        
        if let cache = filteredHabitCache,
           cache.date == targetDate,
           cache.today == today,
           cache.revision == dataRevision {
            return cache.items
        }

        let result: [HabitListItem]
        do {
            result = try homeQuery.habitItems(
                on: targetDate,
                relativeTo: today,
                calendar: calendar
            )
        } catch {
            Logger.error("Failed to load Habit home items: \(error)")
            result = []
        }

        filteredHabitCache = (targetDate, today, dataRevision, result)
        return result
    }
    private(set) var selectedDate: Date = Date()
    var weekStartsOnMonday: Bool {
        userProfile?.weekStartsOnMonday ?? true
    }
    
    var colorScheme: AppColorScheme {
        userProfile?.colorScheme ?? .light
    }
    
    var orderedWeekdays: [Int] {
        weekStartsOnMonday
        ? [1, 2, 3, 4, 5, 6, 0]
        : [0, 1, 2, 3, 4, 5, 6]
    }
    
    // MARK: - PROFILE
    var userProfile: UserProfile?
    
    // MARK: - Constructor
    init(
        repository: any HabitRepository,
        homeQuery: any HabitHomeQuerying,
        notificationScheduler: any HabitNotificationScheduling
    ) {
        self.repository = repository
        self.homeQuery = homeQuery
        self.notificationScheduler = notificationScheduler
        fetchUserProfile()
        fetchHabits()
    }
}

// MARK: - Home

extension HabitViewModel {
    func refreshLocalizedText() {
        homeTitle = selectedDate.isToday()
        ? AppString.Home.today
        : selectedDate.toString(withFormat: .dayNameWithNo)
    }
    
    func backToday() {
        didChangeSelecteDate(Date())
    }
    
    func didChangeSelecteDate(_ date: Date) {
        selectedDate = date
        filteredHabitCache = nil
        if selectedDate.isToday() {
            homeTitle = AppString.Home.today
        } else {
            homeTitle = selectedDate.toString(withFormat: .dayNameWithNo)
        }
    }
    
    func weekDaySummaries(for dates: [Date]) -> [WeekDaySummary] {
        let calendar = AppCalendar.current
        let progress: [HabitDayProgress]

        do {
            progress = try homeQuery.dayProgress(for: dates, calendar: calendar)
        } catch {
            Logger.error("Failed to load Habit day progress: \(error)")
            progress = []
        }

        return progress.map {
            WeekDaySummary(
                date: $0.date,
                isSelected: calendar.isDate($0.date, inSameDayAs: selectedDate),
                isToday: calendar.isDateInToday($0.date),
                isComplete: $0.isComplete,
                completionRatio: $0.completionRatio
            )
        }
    }
}

// MARK: - Profile

extension HabitViewModel {
    func fetchUserProfile() {
        do {
            if let existingProfile = try repository.fetchUserProfile() {
                userProfile = existingProfile
                AppCalendar.weekStartsOnMonday = existingProfile.weekStartsOnMonday
            } else {
                let profile = UserProfile()
                repository.addProfile(profile)
                userProfile = profile
                AppCalendar.weekStartsOnMonday = profile.weekStartsOnMonday
                _ = save()
            }
        } catch {
            Logger.error("Failed to fetch user profile: \(error)")
            userProfile = nil
        }
    }
    
    func updateWeekStartsOnMonday(_ enabled: Bool) {
        if userProfile == nil {
            fetchUserProfile()
        }
        
        userProfile?.weekStartsOnMonday = enabled
        AppCalendar.weekStartsOnMonday = enabled
        _ = save()
    }
    
    func updateColorScheme(_ colorScheme: AppColorScheme) {
        if userProfile == nil {
            fetchUserProfile()
        }
        
        userProfile?.colorScheme = colorScheme
        _ = save()
    }
    
    func updateProfile(displayName: String, avatarOriginalData: Data?, avatarData: Data?) {
        if userProfile == nil {
            fetchUserProfile()
        }
        
        userProfile?.displayName = displayName
        userProfile?.avatarOriginalData = avatarOriginalData
        userProfile?.avatarData = avatarData
        _ = save()
    }
}

// MARK: - Reload

extension HabitViewModel {
    func reloadAfterBackupImport() {
        fetchUserProfile()
        fetchHabits()
        rescheduleHabitNotifications()
    }
}

// MARK: - Habits

extension HabitViewModel {
    func fetchHabits() {
        invalidateHabitCache()
        do {
            habits = try repository.fetchHabits()
        } catch {
            Logger.error("Failed to fetch habits: \(error)")
            habits = []
        }
    }
    
    func prepareForPersistentDataReplacement() {
        userProfile = nil
        invalidateHabitCache()
        habits = []
    }
    
    func addHabit(_ habit: Habit, reminders: [HabitReminderConfiguration] = []) {
        habit.sortOrder = nextHabitSortOrder()
        replaceReminders(for: habit, with: reminders)
        repository.addHabit(habit)
        if save() {
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: habit)
        }
    }
    
    func updateHabit(
        _ habit: Habit,
        name: String,
        description: String,
        icon: String,
        colorHex: String,
        startDate: Date,
        endDate: Date?,
        frequency: HabitFrequency,
        targetDaysOfWeek: [Int],
        goalType: GoalType,
        goalCount: Int,
        goalUnit: String,
        reminders: [HabitReminderConfiguration]
    ) {
        notificationScheduler.cancelNotifications(for: habit)
        
        habit.name = name
        habit.habitDescription = description
        habit.icon = icon
        habit.colorHex = colorHex
        habit.startDate = startDate
        habit.endDate = endDate
        habit.frequency = frequency
        habit.targetDaysOfWeek = targetDaysOfWeek
        habit.goalType = goalType
        habit.goalCount = goalCount
        habit.goalUnit = goalUnit
        
        replaceReminders(for: habit, with: reminders)
        updateStreaks(for: habit)
        
        if save() {
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: habit)
        } else {
            fetchHabits()
        }
    }
    
    func nextVersionNumber(after habit: Habit) -> Int {
        let seriesID = habit.effectiveSeriesID
        let highestVersion = habits
            .filter { $0.effectiveSeriesID == seriesID }
            .map(\.displayVersionNumber)
            .max() ?? habit.displayVersionNumber
        
        return highestVersion + 1
    }
    
    func previousVersion(for habit: Habit) -> Habit? {
        guard let replacedHabitID = habit.replacedHabitID else {
            return nil
        }
        
        return self.habit(id: replacedHabitID)
    }
    
    func nextVersion(after habit: Habit) -> Habit? {
        habits
            .filter { $0.replacedHabitID == habit.id }
            .sorted { $0.displayVersionNumber < $1.displayVersionNumber }
            .first
    }
    
    func habitSeries(containing habit: Habit) -> [Habit] {
        let seriesID = habit.effectiveSeriesID
        
        return habits
            .filter { $0.effectiveSeriesID == seriesID }
            .sorted {
                if $0.displayVersionNumber != $1.displayVersionNumber {
                    return $0.displayVersionNumber < $1.displayVersionNumber
                }
                
                return $0.createdAt < $1.createdAt
            }
    }
    
    @discardableResult
    func createHabitVersion(
        replacing oldHabit: Habit,
        with newHabit: Habit,
        reminders: [HabitReminderConfiguration]
    ) -> Habit? {
        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let minimumNewStartDay = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let requestedNewStartDay = calendar.startOfDay(for: newHabit.effectiveStartDate)
        let newStartDay = max(requestedNewStartDay, minimumNewStartDay)
        let oldStartDay = calendar.startOfDay(for: oldHabit.effectiveStartDate)
        let oldEndDay = calendar.date(byAdding: .day, value: -1, to: newStartDay) ?? today
        let safeOldEndDay = max(oldEndDay, oldStartDay)
        let versionNumber = nextVersionNumber(after: oldHabit)
        
        notificationScheduler.cancelNotifications(for: oldHabit)
        
        oldHabit.endDate = oldHabit.endDate.map {
            min(max(calendar.startOfDay(for: $0), oldStartDay), safeOldEndDay)
        } ?? safeOldEndDay
        oldHabit.archivedAt = Date()
        
        newHabit.startDate = newStartDay
        newHabit.seriesID = oldHabit.effectiveSeriesID
        newHabit.replacedHabitID = oldHabit.id
        newHabit.versionNumber = versionNumber
        newHabit.sortOrder = oldHabit.sortOrder
        
        replaceReminders(for: newHabit, with: reminders)
        updateStreaks(for: oldHabit)
        repository.addHabit(newHabit)
        
        guard save() else {
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: oldHabit)
            return nil
        }
        
        fetchHabits()
        notificationScheduler.rescheduleNotifications(for: newHabit)
        return habit(id: newHabit.id) ?? newHabit
    }
    
    @discardableResult
    func archiveHabit(_ habit: Habit) -> Bool {
        guard habit.archivedAt == nil else { return true }
        
        habit.archivedAt = Date()
        notificationScheduler.cancelNotifications(for: habit)
        
        if save() {
            fetchHabits()
            return true
        } else {
            habit.archivedAt = nil
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: habit)
            return false
        }
    }
    
    @discardableResult
    func unarchiveHabit(_ habit: Habit) -> Bool {
        guard habit.archivedAt != nil else { return true }
        
        let archivedAt = habit.archivedAt
        habit.archivedAt = nil
        
        if save() {
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: habit)
            return true
        } else {
            habit.archivedAt = archivedAt
            fetchHabits()
            notificationScheduler.cancelNotifications(for: habit)
            return false
        }
    }
    
    func habit(id: UUID) -> Habit? {
        habits.first {
            $0.modelContext != nil && !$0.isDeleted && $0.id == id
        }
    }
    
    @discardableResult
    func deleteHabit(id: UUID) -> Bool {
        guard let habit = habit(id: id) else { return false }
        let replacementHabitID = habit.replacedHabitID
        let followingVersions = habits.filter { $0.replacedHabitID == id }
        
        for followingVersion in followingVersions {
            followingVersion.replacedHabitID = replacementHabitID
        }
        
        invalidateHabitCache()
        habits.removeAll { $0.id == id }
        notificationScheduler.cancelNotifications(for: habit)
        
        repository.removeHabit(habit)
        
        guard save() else {
            fetchHabits()
            notificationScheduler.rescheduleNotifications(for: habit)
            return false
        }
        
        fetchHabits()
        return true
    }
    
    @discardableResult
    func deleteHabitSeries(containing habit: Habit) -> Bool {
        let seriesHabits = habitSeries(containing: habit)
        guard !seriesHabits.isEmpty else { return false }
        
        let seriesHabitIDs = Set(seriesHabits.map(\.id))
        invalidateHabitCache()
        habits.removeAll { seriesHabitIDs.contains($0.id) }
        
        for habit in seriesHabits {
            notificationScheduler.cancelNotifications(for: habit)
            repository.removeHabit(habit)
        }
        
        guard save() else {
            fetchHabits()
            for habit in seriesHabits where !habit.isArchived {
                notificationScheduler.rescheduleNotifications(for: habit)
            }
            return false
        }
        
        fetchHabits()
        return true
    }
}

// MARK: - Habit Entries
extension HabitViewModel {
    func updateHabitEntry(_ habit: Habit, completedCount: Int, note: String? = nil) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.updateProgress(
            for: habit,
            on: selectedDate,
            completedCount: completedCount,
            note: note,
            calendar: calendar
        )
        applyEntryMutation(mutation, to: habit)
    }
    
    func skipHabitEntry(_ habit: Habit) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.skip(
            habit,
            on: selectedDate,
            calendar: calendar
        )
        applyEntryMutation(mutation, to: habit)
    }
    
    func resetHabitEntry(_ habit: Habit) {
        let calendar = AppCalendar.current
        let mutation = habitEntryMutationPolicy.reset(
            habit,
            on: selectedDate,
            calendar: calendar
        )
        if case .updated = mutation {
            Haptic.warning()
        }
        applyEntryMutation(mutation, to: habit)
    }
}

// MARK: - Streak Helpers

private extension HabitViewModel {
    func applyEntryMutation(_ mutation: HabitEntryMutation, to habit: Habit) {
        switch mutation {
        case .unchanged:
            return
        case .rejected:
            Haptic.warning()
            return
        case .updated:
            break
        case .inserted(let entry):
            repository.addEntry(entry)
        }

        updateStreaks(for: habit)
        invalidateHabitCache()
        _ = save()
    }

    func invalidateHabitCache() {
        dataRevision &+= 1
        filteredHabitCache = nil
    }
    
    func updateStreaks(for habit: Habit) {
        let result = habitStreakCalculator.calculate(for: habit, calendar: AppCalendar.current)
        habit.currentStreak = result.currentStreak
        habit.longestStreak = result.longestStreak
        habit.lastCompletedDate = result.lastCompletedDate
    }
    
    func replaceReminders(
        for habit: Habit,
        with configurations: [HabitReminderConfiguration]
    ) {
        for reminder in habit.reminders {
            repository.removeReminder(reminder)
        }
        habit.reminders.removeAll()
        
        for configuration in configurations.sorted(by: { $0.time < $1.time }) {
            let reminder = HabitReminder(
                time: configuration.time,
                daysOfWeek: configuration.daysOfWeek,
                isEnabled: configuration.isEnabled
            )
            reminder.id = configuration.id
            reminder.habit = habit
            habit.reminders.append(reminder)
            repository.addReminder(reminder)
        }
    }
    
}

// MARK: - Scheduling
extension HabitViewModel {
    func rescheduleHabitNotifications() {
        for habit in habits {
            notificationScheduler.rescheduleNotifications(for: habit)
        }
    }
}

// MARK: - Persistence

private extension HabitViewModel {
    func save() -> Bool {
        do {
            try repository.save()
            return true
        } catch {
            Logger.error("Failed to save context: \(error)")
            return false
        }
    }
}

private extension HabitViewModel {
    func nextHabitSortOrder() -> Int {
        (habits.map(\.sortOrder).max() ?? -1) + 1
    }
}
