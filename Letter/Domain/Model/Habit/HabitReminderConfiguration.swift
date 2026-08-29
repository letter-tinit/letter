import Foundation

struct HabitReminderConfiguration: Identifiable {
    let id: UUID
    let notificationID: String
    var time: Date
    var daysOfWeek: [Int]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        notificationID: String? = nil,
        time: Date,
        daysOfWeek: [Int] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.notificationID = notificationID ?? id.uuidString
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
    }
}
