import Foundation
@testable import Domain

@MainActor
final class FakeHabitNotificationRepository: HabitNotificationRepository {
    var rescheduledHabitIDs: [UUID] = []
    var cancelledHabitIDs: [UUID] = []

    func rescheduleNotifications(for habit: HabitSnapshot) {
        rescheduledHabitIDs.append(habit.id)
    }

    func cancelNotifications(for habit: HabitSnapshot) {
        cancelledHabitIDs.append(habit.id)
    }
}
