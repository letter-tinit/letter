import Foundation
import Utility

public struct HabitReminderConfiguration: Identifiable {
    public let id: UUID
    public let notificationID: String
    public var time: Date
    public var daysOfWeek: [Int]
    public var isEnabled: Bool

    public init(
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
