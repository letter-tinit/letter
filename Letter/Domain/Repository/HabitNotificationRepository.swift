@MainActor
protocol HabitNotificationRepository {
    func rescheduleNotifications(for habit: Habit)
    func cancelNotifications(for habit: Habit)
    func rescheduleNotifications(for habit: HabitSnapshot)
    func cancelNotifications(for habit: HabitSnapshot)
}
