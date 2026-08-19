import Foundation
import SwiftData

@Model
final class BalanceMonth {
    @Attribute(.unique) var id: Date
    var monthStart: Date
    var isLocked: Bool

    init(monthStart: Date, isLocked: Bool = false) {
        let normalized = Calendar.current.startOfMonth(for: monthStart)
        self.id = normalized
        self.monthStart = normalized
        self.isLocked = isLocked
    }
}
