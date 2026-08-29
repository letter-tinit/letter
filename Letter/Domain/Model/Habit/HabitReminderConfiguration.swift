import Foundation

struct HabitReminderConfiguration: Identifiable {
    let id: UUID
    var time: Date
    var daysOfWeek: [Int]
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        time: Date,
        daysOfWeek: [Int] = [],
        isEnabled: Bool = true
    ) {
        self.id = id
        self.time = time
        self.daysOfWeek = daysOfWeek
        self.isEnabled = isEnabled
    }
}
