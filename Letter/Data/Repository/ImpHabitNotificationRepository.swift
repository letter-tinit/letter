//
//  ImpHabitNotificationRepository.swift
//  Letter
//
//  Created by Codex on 27/5/26.
//

import Foundation
@preconcurrency import UserNotifications

@MainActor
struct ImpHabitNotificationRepository: HabitNotificationRepository {
    func rescheduleNotifications(for habit: HabitSnapshot) {
        cancelNotifications(for: habit)

        guard habit.archivedAt == nil else {
            return
        }

        guard !Self.hasEnded(habit) else {
            return
        }

        let enabledReminders = habit.reminders.filter(\.isEnabled)
        guard !enabledReminders.isEmpty else {
            return
        }

        Self.requestAuthorizationIfNeeded { isAuthorized in
            guard isAuthorized else {
                return
            }

            for reminder in enabledReminders {
                Self.scheduleReminder(reminder, for: habit)
            }
        }
    }

    func cancelNotifications(for habit: HabitSnapshot) {
        var identifiers: [String] = []
        for reminder in habit.reminders {
            for weekday in 0...6 {
                identifiers.append(Self.notificationIdentifier(for: reminder, weekday: weekday))
            }
        }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func requestAuthorizationIfNeeded(completion: @escaping (Bool) -> Void) {
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    completion(true)
                }
            case .notDetermined:
                UNUserNotificationCenter.current().requestAuthorization(
                    options: [.alert, .badge, .sound]
                ) { isGranted, error in
                    if let error {
                        let message = "Failed to request notification authorization: \(error)"
                        DispatchQueue.main.async {
                            Logger.error(message)
                        }
                    }
                    DispatchQueue.main.async {
                        completion(isGranted)
                    }
                }
            case .denied:
                DispatchQueue.main.async {
                    completion(false)
                }
            @unknown default:
                DispatchQueue.main.async {
                    completion(false)
                }
            }
        }
    }

    private static func scheduleReminder(
        _ reminder: HabitReminderConfiguration,
        for habit: HabitSnapshot
    ) {
        let weekdays = notificationWeekdays(for: reminder, habit: habit)

        for weekday in weekdays {
            let trigger: UNCalendarNotificationTrigger
            if shouldScheduleRepeatingNotifications(for: habit) {
                var dateComponents = AppCalendar.current.dateComponents([.hour, .minute], from: reminder.time)
                dateComponents.weekday = weekday + 1
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
            } else if let fireDate = nextFireDate(for: reminder, habit: habit, weekday: weekday) {
                let dateComponents = AppCalendar.current.dateComponents(
                    [.year, .month, .day, .hour, .minute],
                    from: fireDate
                )
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            } else {
                continue
            }

            let content = UNMutableNotificationContent()
            content.title = habit.name
            content.body = reminderBody(for: habit)
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: notificationIdentifier(for: reminder, weekday: weekday),
                content: content,
                trigger: trigger
            )

            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    let message = "Failed to schedule habit notification: \(error)"
                    DispatchQueue.main.async {
                        Logger.error(message)
                    }
                }
            }
        }
    }

    private static func shouldScheduleRepeatingNotifications(for habit: HabitSnapshot) -> Bool {
        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let startDay = calendar.startOfDay(for: habit.effectiveStartDate)

        return startDay <= today
    }

    private static func hasEnded(_ habit: HabitSnapshot) -> Bool {
        guard let endDate = habit.endDate else {
            return false
        }

        let calendar = AppCalendar.current
        let today = calendar.startOfDay(for: Date())
        let endDay = calendar.startOfDay(for: endDate)

        return endDay < today
    }

    private static func nextFireDate(
        for reminder: HabitReminderConfiguration,
        habit: HabitSnapshot,
        weekday: Int
    ) -> Date? {
        let calendar = AppCalendar.current
        let now = Date()
        let today = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: habit.effectiveStartDate)
        let firstEligibleDay = max(today, startDay)

        guard let candidate = nextDate(
            matching: weekday,
            reminder: reminder,
            onOrAfter: firstEligibleDay,
            calendar: calendar
        ) else {
            return nil
        }

        if let endDate = habit.endDate {
            let endDay = calendar.startOfDay(for: endDate)
            guard calendar.startOfDay(for: candidate) <= endDay else {
                return nil
            }
        }

        if candidate <= now {
            guard let nextWeek = calendar.date(byAdding: .day, value: 7, to: candidate) else {
                return nil
            }

            if let endDate = habit.endDate {
                let endDay = calendar.startOfDay(for: endDate)
                guard calendar.startOfDay(for: nextWeek) <= endDay else {
                    return nil
                }
            }

            return nextWeek
        }

        return candidate
    }

    private static func nextDate(
        matching weekday: Int,
        reminder: HabitReminderConfiguration,
        onOrAfter date: Date,
        calendar: Calendar
    ) -> Date? {
        let targetWeekday = weekday + 1
        let currentWeekday = calendar.component(.weekday, from: date)
        let daysUntilTarget = (targetWeekday - currentWeekday + 7) % 7

        guard let targetDay = calendar.date(byAdding: .day, value: daysUntilTarget, to: date) else {
            return nil
        }

        let timeComponents = calendar.dateComponents([.hour, .minute], from: reminder.time)
        return calendar.date(
            bySettingHour: timeComponents.hour ?? 0,
            minute: timeComponents.minute ?? 0,
            second: 0,
            of: targetDay
        )
    }

    private static func reminderBody(for habit: HabitSnapshot) -> String {
        switch habit.goalType {
        case .todo:
            "Time to complete this habit."
        case .count:
            "Time to work on \(habit.goalCount) \(habit.goalUnit)."
        }
    }

    private static func notificationWeekdays(
        for reminder: HabitReminderConfiguration,
        habit: HabitSnapshot
    ) -> [Int] {
        let weekdays = reminder.daysOfWeek.isEmpty ? scheduledWeekdays(for: habit) : reminder.daysOfWeek
        return weekdays.filter { (0...6).contains($0) }.sorted()
    }

    private static func scheduledWeekdays(for habit: HabitSnapshot) -> [Int] {
        switch habit.frequency {
        case .daily:
            Array(0...6)
        case .weekday:
            Array(1...5)
        case .weekend:
            [0, 6]
        case .custom:
            habit.targetDaysOfWeek
        }
    }

    private static func notificationIdentifier(
        for reminder: HabitReminderConfiguration,
        weekday: Int
    ) -> String {
        "\(reminder.notificationID)-weekday-\(weekday)"
    }
}
