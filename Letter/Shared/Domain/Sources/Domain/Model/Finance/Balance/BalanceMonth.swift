import Foundation
import Utility

public final class BalanceMonth: Identifiable, Hashable {
    public var id: Date
    public var monthStart: Date
    public var isLocked: Bool

    public init(monthStart: Date, isLocked: Bool = false) {
        let normalized = Calendar.current.startOfMonth(for: monthStart)
        self.id = normalized
        self.monthStart = normalized
        self.isLocked = isLocked
    }


    public static func == (lhs: BalanceMonth, rhs: BalanceMonth) -> Bool { lhs.id == rhs.id }

    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
