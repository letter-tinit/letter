import Foundation

final class BalanceMonth: Identifiable, Hashable {
    var id: Date
    var monthStart: Date
    var isLocked: Bool

    init(monthStart: Date, isLocked: Bool = false) {
        let normalized = Calendar.current.startOfMonth(for: monthStart)
        self.id = normalized
        self.monthStart = normalized
        self.isLocked = isLocked
    }


    static func == (lhs: BalanceMonth, rhs: BalanceMonth) -> Bool { lhs.id == rhs.id }

    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
