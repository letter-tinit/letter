import Foundation

public struct BalanceMonth: Identifiable, Hashable {
    public var id: Date
    public var monthStart: Date
    public var isLocked: Bool

    public init(monthStart: Date, isLocked: Bool = false) {
        self.id = monthStart
        self.monthStart = monthStart
        self.isLocked = isLocked
    }
}
