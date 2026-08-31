import Foundation
import Observation
import Domain
import Core
import Utility
import Styleguide

@Observable
@MainActor
public final class CreateHabitViewModel {
    private let mode: HabitFormMode
    private let formUseCase: any HabitFormUseCase
    private let calendarPreferences: CalendarPreferences

    public var screenTitle: String
    public var name: String
    public var icon: String
    public var habitDescription: String
    public var colorHex: String
    public var startDate: Date
    public var hasEndDate: Bool
    public var endDate: Date
    public var frequency: HabitFrequency
    public var selectedDays: Set<Int>
    public var goalType: GoalType
    public var goalCountText: String
    public var goalUnit: String
    public var reminders: [HabitReminderConfiguration]
    private(set) var errorMessage: String?

    public let sourceVersionNumber: Int?
    private let sourceFrequency: HabitFrequency?

    public var orderedWeekdays: [Int] {
        calendarPreferences.orderedWeekdays
    }

    public var sourceRepeatTitle: String {
        switch sourceFrequency {
        case .daily: "habit.repeat.daily".localized
        case .weekday: "habit.repeat.weekdays".localized
        case .weekend: "habit.repeat.weekends".localized
        case .custom: "habit.repeat.custom".localized
        case nil: "habit.common.none".localized
        }
    }

    public var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    public var isCreatingVersion: Bool {
        if case .newVersion = mode { return true }
        return false
    }

    public var targetVersionNumber: Int {
        (sourceVersionNumber ?? 0) + 1
    }

    public var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var trimmedGoalUnit: String {
        goalUnit.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var goalCount: Int {
        goalType == .todo ? 1 : Int(goalCountText) ?? 0
    }

    public var locksGoalAndSchedule: Bool { isEditing }

    public var normalizedStartDate: Date {
        calendarPreferences.calendar.startOfDay(for: startDate)
    }

    public var normalizedEndDate: Date {
        calendarPreferences.calendar.startOfDay(for: endDate)
    }

    public var minimumStartDate: Date? {
        guard isCreatingVersion else { return nil }
        let calendar = calendarPreferences.calendar
        let today = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .day, value: 1, to: today) ?? today
    }

    public var canSave: Bool {
        let startDateIsAllowed = minimumStartDate.map {
            normalizedStartDate >= $0
        } ?? true

        return !trimmedName.isEmpty &&
            goalCount > 0 &&
            !trimmedGoalUnit.isEmpty &&
            startDateIsAllowed &&
            (!hasEndDate || normalizedEndDate >= normalizedStartDate) &&
            (frequency != .custom || !selectedDays.isEmpty)
    }

    public init(
        mode: HabitFormMode,
        source: HabitSnapshot?,
        formUseCase: any HabitFormUseCase,
        calendarPreferences: CalendarPreferences
    ) {
        self.mode = mode
        self.formUseCase = formUseCase
        self.calendarPreferences = calendarPreferences

        let calendar = calendarPreferences.calendar
        let today = calendar.startOfDay(for: Date())
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let createsVersion = if case .newVersion = mode { true } else { false }
        let initialStart = createsVersion ? tomorrow : source?.effectiveStartDate ?? today
        let inheritedEnd = source?.endDate.flatMap {
            !createsVersion || calendar.startOfDay(for: $0) >= tomorrow ? $0 : nil
        }

        switch mode {
        case .create:
            screenTitle = "habit.form.new.title".localized
        case .edit:
            screenTitle = "habit.form.edit.title".localized
        case .newVersion:
            screenTitle = "habit.version.number".localized((source?.displayVersionNumber ?? 1) + 1)
        }

        name = source?.name ?? ""
        icon = source?.icon ?? "star.fill"
        habitDescription = source?.habitDescription ?? ""
        colorHex = source?.colorHex ?? AppConstant.defaultColor
        startDate = initialStart
        hasEndDate = inheritedEnd != nil
        endDate = inheritedEnd ?? initialStart
        frequency = source?.frequency ?? .daily
        selectedDays = Set(source?.targetDaysOfWeek.isEmpty == false
            ? source?.targetDaysOfWeek ?? []
            : Array(0...6))
        goalType = source?.goalType ?? .count
        goalCountText = String(source?.goalCount ?? 1)
        goalUnit = source?.goalUnit ?? "habit.goal.times".localized
        reminders = source?.reminders
            .map {
                HabitReminderConfiguration(
                    id: createsVersion ? UUID() : $0.id,
                    notificationID: createsVersion ? nil : $0.notificationID,
                    time: $0.time,
                    daysOfWeek: $0.daysOfWeek,
                    isEnabled: $0.isEnabled
                )
            }
            .sorted { $0.time < $1.time } ?? []
        sourceVersionNumber = source?.displayVersionNumber
        sourceFrequency = source?.frequency
    }

    public func save() -> UUID? {
        guard canSave else { return nil }

        let draft = HabitDraft(
            name: trimmedName,
            description: habitDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            icon: icon,
            colorHex: colorHex,
            startDate: normalizedStartDate,
            endDate: hasEndDate ? normalizedEndDate : nil,
            frequency: frequency,
            targetDaysOfWeek: Array(selectedDays).sorted(),
            goalType: goalType,
            goalCount: goalCount,
            goalUnit: trimmedGoalUnit,
            reminders: reminders
        )

        do {
            errorMessage = nil
            return try formUseCase.save(
                mode: mode,
                draft: draft,
                calendar: calendarPreferences.calendar,
                now: Date()
            )
        } catch {
            Logger.error("Failed to save Habit form: \(error)")
            errorMessage = error.localizedDescription
            return nil
        }
    }

    public func selectFrequency(_ frequency: HabitFrequency) {
        switch frequency {
        case .daily: selectedDays = Set(0...6)
        case .weekday: selectedDays = [1, 2, 3, 4, 5]
        case .weekend: selectedDays = [0, 6]
        case .custom: break
        }
    }

    public func toggleWeekday(_ weekday: Int) {
        if selectedDays.contains(weekday) {
            selectedDays.remove(weekday)
        } else {
            selectedDays.insert(weekday)
        }
        synchronizeFrequency()
    }

    public func addReminder() {
        let nextTime = calendarPreferences.calendar.date(
            bySettingHour: 9,
            minute: 0,
            second: 0,
            of: Date()
        ) ?? Date()
        reminders.append(HabitReminderConfiguration(time: nextTime))
        reminders.sort { $0.time < $1.time }
    }

    public func startOfDay(for date: Date) -> Date {
        calendarPreferences.calendar.startOfDay(for: date)
    }

    public func deleteReminder(id: UUID) {
        reminders.removeAll { $0.id == id }
    }

    private func synchronizeFrequency() {
        if selectedDays == Set(0...6) {
            frequency = .daily
        } else if selectedDays == Set(1...5) {
            frequency = .weekday
        } else if selectedDays == Set([0, 6]) {
            frequency = .weekend
        } else {
            frequency = .custom
        }
    }
}
