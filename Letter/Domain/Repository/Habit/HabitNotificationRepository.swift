@MainActor
protocol HabitNotificationRepository {
    func rescheduleNotifications(for habit: HabitSnapshot)
    func cancelNotifications(for habit: HabitSnapshot)
}
