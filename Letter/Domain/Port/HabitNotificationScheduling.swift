@MainActor
protocol HabitNotificationScheduling {
    func rescheduleNotifications(for habit: Habit)
    func cancelNotifications(for habit: Habit)
}
