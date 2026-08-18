//
//  HabitViewModel.swift
//  Habit
//
//  Created by TiniT on 28/4/26.
//

import Observation
import Foundation

@Observable
final class HabitViewModel {
    // MARK: - Dependencies
    private let repository: any HabitRepository
    private let habitSchedule: HabitSchedule = HabitSchedule()
    private let habitStreakCalculator = HabitStreakCalculator()
    private let statisticsCalculator = HabitStatisticsCalculator()
    private let notificationScheduler: any HabitNotificationScheduling

    var homeTitle: String = AppString.Home.today
    var profileTitle: String = AppString.ScreenTitle.profile
    var habits: [Habit] = []
    @ObservationIgnored private var filteredHabitCache: (date: Date, revision: Int, habits: [Habit])?
    @ObservationIgnored private var dataRevision = 0

    var filteredHabit: [Habit] {
        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)

        if let cache = filteredHabitCache,
           cache.date == targetDate,
           cache.revision == dataRevision {
            return cache.habits
        }

        let scheduledHabits = habits.filter {
            habitSchedule.isScheduled($0, on: targetDate, calendar: calendar)
        }
        let closedByHabitID = Dictionary(
            uniqueKeysWithValues: scheduledHabits.map {
                ($0.id, isClosed(for: $0, on: targetDate, calendar: calendar))
            }
        )

        let result = scheduledHabits
            .sorted { first, second in
                let firstIsClosed = closedByHabitID[first.id] ?? false
                let secondIsClosed = closedByHabitID[second.id] ?? false

                if firstIsClosed != secondIsClosed {
                    return !firstIsClosed
                }

                return first.sortOrder < second.sortOrder
            }

        filteredHabitCache = (targetDate, dataRevision, result)
        return result
    }
    var selectedHabit: Habit?
    private(set) var selectedDate: Date = Date()
    var weekStartsOnMonday: Bool {
        userProfile?.weekStartsOnMonday ?? true
    }

    var colorScheme: AppColorScheme {
        userProfile?.colorScheme ?? .system
    }

    var orderedWeekdays: [Int] {
        weekStartsOnMonday
        ? [1, 2, 3, 4, 5, 6, 0]
        : [0, 1, 2, 3, 4, 5, 6]
    }

    // MARK: - STATISTICAL
    var usesCompactStatisticsView: Bool = false {
        didSet {
            guard usesCompactStatisticsView != oldValue else {
                return
            }
            updateUsesSimplifiedStatisticsMode(usesCompactStatisticsView)
        }
    }

    // MARK: - PROFILE
    var userProfile: UserProfile?

    // MARK: - Constructor
    init(
        repository: any HabitRepository,
        notificationScheduler: any HabitNotificationScheduling
    ) {
        self.repository = repository
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
        if userProfile == nil {
            profileTitle = AppString.ScreenTitle.profile
        }
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

    func isHabit(_ habit: Habit) -> Bool {
        habitSchedule.isScheduled(habit, on: selectedDate, calendar: AppCalendar.current)
    }

    func isScheduled(_ habit: Habit, on date: Date) -> Bool {
        habitSchedule.isScheduled(habit, on: date, calendar: AppCalendar.current)
    }

    /// Input: a date param
    /// Output: check is input date is selected Date or not
    func isSelectedDay(_ date: Date) -> Bool {
        date.isEqual(with: selectedDate)
    }

    func weekDaySummaries(for dates: [Date]) -> [WeekDaySummary] {
        let calendar = AppCalendar.current
        let targetDates = Set(dates.map { calendar.startOfDay(for: $0) })
        let entriesByHabitID = entriesByHabitID(for: targetDates, calendar: calendar)

        return dates.map { date in
            let targetDate = calendar.startOfDay(for: date)
            let scheduledHabits = habits.filter {
                habitSchedule.isScheduled($0, on: targetDate, calendar: calendar)
            }

            guard !scheduledHabits.isEmpty else {
                return WeekDaySummary(
                    date: date,
                    isSelected: date.isEqual(with: selectedDate),
                    isToday: date.isToday(),
                    isComplete: false,
                    completionRatio: 0
                )
            }

            var activeHabitCount = 0
            let totalRatio = scheduledHabits.reduce(0.0) { result, habit in
                guard habit.goalCount > 0 else {
                    return result
                }

                let entry = entriesByHabitID[habit.id]?[targetDate]
                guard entry?.isSkipped != true else {
                    return result
                }

                activeHabitCount += 1
                let completedCount = entry?.completedCount ?? 0
                let ratio = min(Double(completedCount) / Double(habit.goalCount), 1.0)
                return result + ratio
            }
            let completionRatio = activeHabitCount == 0 ? 1 : totalRatio / Double(activeHabitCount)

            return WeekDaySummary(
                date: date,
                isSelected: date.isEqual(with: selectedDate),
                isToday: date.isToday(),
                isComplete: completionRatio == 1.0,
                completionRatio: completionRatio
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
                usesCompactStatisticsView = existingProfile.usesSimplifiedStatisticsMode
                profileTitle = userProfile?.displayName ?? AppString.ScreenTitle.profile
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

    func updateUsesSimplifiedStatisticsMode(_ enabled: Bool) {
        if userProfile == nil {
            fetchUserProfile()
        }

        userProfile?.usesSimplifiedStatisticsMode = enabled
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
        do {
            habits = try repository.fetchHabits()
        } catch {
            Logger.error("Failed to fetch habits: \(error)")
            habits = []
        }
        invalidateHabitCache()
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

    func moveFilteredHabits(from source: IndexSet, to destination: Int) {
        let visibleHabitIDs = filteredHabit.map(\.id)
        let visibleHabitIDSet = Set(visibleHabitIDs)
        let reorderedVisibleIDs = visibleHabitIDs.moving(from: source, to: destination)

        var reorderedVisibleIDIndex = 0
        let reorderedGlobalIDs = habits.map { habit in
            guard visibleHabitIDSet.contains(habit.id) else {
                return habit.id
            }

            defer {
                reorderedVisibleIDIndex += 1
            }
            return reorderedVisibleIDs[reorderedVisibleIDIndex]
        }

        for (index, habitID) in reorderedGlobalIDs.enumerated() {
            habit(id: habitID)?.sortOrder = index
        }

        if save() {
            fetchHabits()
        } else {
            fetchHabits()
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
        habits.first { $0.id == id }
    }

    @discardableResult
    func deleteHabit(id: UUID) -> Bool {
        guard let habit = habit(id: id) else { return false }
        let replacementHabitID = habit.replacedHabitID
        let followingVersions = habits.filter { $0.replacedHabitID == id }

        for followingVersion in followingVersions {
            followingVersion.replacedHabitID = replacementHabitID
        }

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
        if let selectedHabit, seriesHabitIDs.contains(selectedHabit.id) {
            self.selectedHabit = nil
        }

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

    @discardableResult
    func deleteSelectedHabit() -> Bool {
        guard let habit = selectedHabit else { return false }
        let habitID = habit.id
        selectedHabit = nil
        habits.removeAll { $0.id == habitID }
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
}

// MARK: - Habit Entries

extension HabitViewModel {
    var canEditSelectedDateEntry: Bool {
        !selectedDate.isFutureDay()
    }

    func canResetEntry(for habit: Habit) -> Bool {
        canEditSelectedDateEntry || habit.entry(for: selectedDate)?.isSkipped == true
    }

    func isSkipped(_ habit: Habit, on date: Date) -> Bool {
        isSkipped(for: habit, on: date, calendar: AppCalendar.current)
    }

    func updateHabitEntry(_ habit: Habit, completedCount: Int, note: String? = nil) {
        guard canEditSelectedDateEntry else {
            Haptic.warning()
            return
        }

        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)

        if let existingEntry = habit.entries.first(where: {
            $0.date.isEqual(with: targetDate)
        }) {
            guard existingEntry.completedCount != completedCount || existingEntry.isSkipped || note != nil else {
                return
            }

            existingEntry.completedCount = completedCount
            existingEntry.status = .active
            if let note = note {
                existingEntry.note = note
            }
            existingEntry.updatedAt = Date()
        } else {
            guard completedCount > 0 || note?.isEmpty == false else {
                return
            }

            let newEntry = HabitEntry(date: targetDate, completedCount: completedCount, note: note ?? "")
            newEntry.habit = habit
            habit.entries.append(newEntry)
            repository.addEntry(newEntry)
        }

        updateStreaks(for: habit)
        invalidateHabitCache()
        _ = save()
    }

    func skipHabitEntry(_ habit: Habit) {
        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)

        guard habitSchedule.isScheduled(habit, on: targetDate, calendar: calendar) else {
            Haptic.warning()
            return
        }

        if let existingEntry = habit.entries.first(where: {
            $0.date.isEqual(with: targetDate)
        }) {
            guard !existingEntry.isCompleted else {
                Haptic.warning()
                return
            }

            guard !existingEntry.isSkipped || existingEntry.completedCount != 0 else {
                return
            }

            existingEntry.completedCount = 0
            existingEntry.status = .skipped
            existingEntry.updatedAt = Date()
        } else {
            let newEntry = HabitEntry(date: targetDate, status: .skipped)
            newEntry.habit = habit
            habit.entries.append(newEntry)
            repository.addEntry(newEntry)
        }

        updateStreaks(for: habit)
        invalidateHabitCache()
        _ = save()
    }

    func resetHabitEntry(_ habit: Habit) {
        guard canResetEntry(for: habit) else {
            Haptic.warning()
            return
        }

        let calendar = AppCalendar.current
        let targetDate = calendar.startOfDay(for: selectedDate)

        if let existingEntry = habit.entries.first(where: {
            $0.date.isEqual(with: targetDate)
        }) {
            guard existingEntry.completedCount != 0 || existingEntry.isSkipped else {
                return
            }
            Haptic.warning()
            existingEntry.completedCount = 0
            existingEntry.status = .active
            existingEntry.updatedAt = Date()
        }

        updateStreaks(for: habit)
        invalidateHabitCache()
        _ = save()
    }
}

// MARK: - Streak Helpers

private extension HabitViewModel {
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

// MARK: - Performance Helpers

private extension HabitViewModel {
    func entriesByHabitID(
        for targetDates: Set<Date>,
        calendar: Calendar
    ) -> [UUID: [Date: HabitEntry]] {
        habits.reduce(into: [UUID: [Date: HabitEntry]]()) { result, habit in
            for entry in habit.entries {
                let entryDate = calendar.startOfDay(for: entry.date)
                guard targetDates.contains(entryDate) else {
                    continue
                }

                result[habit.id, default: [:]][entryDate] = entry
            }
        }
    }

    func habitEntry(
        for habit: Habit,
        on targetDate: Date,
        calendar: Calendar
    ) -> HabitEntry? {
        let targetDate = calendar.startOfDay(for: targetDate)
        return habit.entries.first {
            calendar.isDate($0.date, inSameDayAs: targetDate)
        }
    }

    func isSkipped(
        for habit: Habit,
        on targetDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard habitSchedule.isScheduled(habit, on: targetDate, calendar: calendar) else {
            return false
        }

        return habitEntry(for: habit, on: targetDate, calendar: calendar)?.isSkipped ?? false
    }

    func isClosed(
        for habit: Habit,
        on targetDate: Date,
        calendar: Calendar
    ) -> Bool {
        isComplete(for: habit, on: targetDate, calendar: calendar) ||
        isSkipped(for: habit, on: targetDate, calendar: calendar)
    }

    func isComplete(
        for habit: Habit,
        on targetDate: Date,
        calendar: Calendar
    ) -> Bool {
        guard habitSchedule.isScheduled(habit, on: targetDate, calendar: calendar),
              habit.goalCount > 0
        else {
            return false
        }

        return habitEntry(for: habit, on: targetDate, calendar: calendar)?.isCompleted ?? false
    }

    func completionRatio(
        on targetDate: Date,
        calendar: Calendar,
        entriesByHabitID: [UUID: [Date: HabitEntry]]
    ) -> Double {
        let targetDate = calendar.startOfDay(for: targetDate)
        let scheduledHabits = habits.filter {
            habitSchedule.isScheduled($0, on: targetDate, calendar: calendar)
        }

        guard !scheduledHabits.isEmpty else {
            return 0
        }

        var activeHabitCount = 0
        let totalRatio = scheduledHabits.reduce(0.0) { result, habit in
            guard habit.goalCount > 0 else {
                return result
            }

            let entry = entriesByHabitID[habit.id]?[targetDate]
            guard entry?.isSkipped != true else {
                return result
            }

            activeHabitCount += 1
            let completedCount = entry?.completedCount ?? 0
            let ratio = min(Double(completedCount) / Double(habit.goalCount), 1.0)
            return result + ratio
        }

        return activeHabitCount == 0 ? 1 : totalRatio / Double(activeHabitCount)
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

// MARK: - Statistics

extension HabitViewModel {
    func monthDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(in: .month, containing: date, calendar: AppCalendar.current)
    }

    func weekDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(in: .weekOfYear, containing: date, calendar: AppCalendar.current)
    }

    func completionRatio(on date: Date) -> Double {
        statisticsCalculator.completionRatio(habits: habits, on: date, calendar: AppCalendar.current)
    }

    func completionRatio(for habit: Habit, on date: Date) -> Double {
        statisticsCalculator.completionRatio(for: habit, on: date, calendar: AppCalendar.current)
    }

    func isComplete(on date: Date) -> Bool {
        statisticsCalculator.isComplete(habits: habits, on: date, calendar: AppCalendar.current)
    }

    func isComplete(for habit: Habit, on date: Date) -> Bool {
        statisticsCalculator.isComplete(for: habit, on: date, calendar: AppCalendar.current)
    }

    func completionRatioForMonth(containing date: Date) -> Double {
        statisticsCalculator.completionRatio(habits: habits, dates: monthDates(containing: date), calendar: AppCalendar.current)
    }

    func completionRatioForMonth(for habit: Habit, containing date: Date) -> Double {
        statisticsCalculator.completionRatio(for: habit, dates: monthDates(containing: date), calendar: AppCalendar.current)
    }

    func completionRatioForWeek(containing date: Date) -> Double {
        statisticsCalculator.completionRatio(habits: habits, dates: weekDates(containing: date), calendar: AppCalendar.current)
    }

    func completionRatioForWeek(for habit: Habit, containing date: Date) -> Double {
        statisticsCalculator.completionRatio(for: habit, dates: weekDates(containing: date), calendar: AppCalendar.current)
    }

    func completionRatioForYear(containing date: Date) -> Double {
        statisticsCalculator.completionRatio(habits: habits, dates: yearDates(containing: date), calendar: AppCalendar.current)
    }

    func completionRatioForYear(for habit: Habit, containing date: Date) -> Double {
        statisticsCalculator.completionRatio(for: habit, dates: yearDates(containing: date), calendar: AppCalendar.current)
    }

    func statisticSummary(
        for habit: Habit,
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        let dates: [Date]

        switch scope {
        case .week:
            dates = weekDates(containing: date)
        case .month:
            dates = monthDates(containing: date)
        case .year:
            dates = yearDates(containing: date)
        }

        return statisticsCalculator.summary(for: habit, dates: dates, calendar: AppCalendar.current)
    }

    func statisticSummary(
        scope: StatisticsScope,
        containing date: Date
    ) -> HabitStatisticSummary {
        let dates: [Date]

        switch scope {
        case .week:
            dates = weekDates(containing: date)
        case .month:
            dates = monthDates(containing: date)
        case .year:
            dates = yearDates(containing: date)
        }

        return statisticsCalculator.aggregateSummary(habits: habits, dates: dates, calendar: AppCalendar.current)
    }

    func statisticSummary(dates: [Date]) -> HabitStatisticSummary {
        statisticsCalculator.aggregateSummary(habits: habits, dates: dates, calendar: AppCalendar.current)
    }

    func yearDates(containing date: Date) -> [Date] {
        statisticsCalculator.dates(in: .year, containing: date, calendar: AppCalendar.current)
    }

    func dates(scope: StatisticsScope, containing date: Date) -> [Date] {
        switch scope {
        case .week:
            weekDates(containing: date)
        case .month:
            monthDates(containing: date)
        case .year:
            yearDates(containing: date)
        }
    }
}

private extension Array {
    func moving(from source: IndexSet, to destination: Int) -> [Element] {
        var result = self
        let movingElements = source.map { result[$0] }

        for index in source.sorted(by: >) {
            result.remove(at: index)
        }

        let removedBeforeDestination = source.filter { $0 < destination }.count
        let adjustedDestination = destination - removedBeforeDestination
        result.insert(contentsOf: movingElements, at: adjustedDestination)

        return result
    }
}
