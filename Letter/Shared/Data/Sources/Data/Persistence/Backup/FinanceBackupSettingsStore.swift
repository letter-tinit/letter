import Foundation
import Domain

public struct FinanceBackupSettingsStore {
    private let userDefaults: UserDefaults
    private let now: () -> Date

    public init(
        userDefaults: UserDefaults = .standard,
        now: @escaping () -> Date = Date.init
    ) {
        self.userDefaults = userDefaults
        self.now = now
    }

    public func loadEarliestMonth() -> Date {
        let timestamp = userDefaults.double(forKey: FinanceSettings.earliestMonthKey)
        return timestamp == 0
            ? FinanceMonth(now()).startDate
            : Date(timeIntervalSinceReferenceDate: timestamp)
    }

    public func restoreEarliestMonth(_ date: Date?) {
        guard let date else { return }
        userDefaults.set(
            FinanceMonth(date).startDate.timeIntervalSinceReferenceDate,
            forKey: FinanceSettings.earliestMonthKey
        )
    }

    public func clearEarliestMonth() {
        userDefaults.removeObject(forKey: FinanceSettings.earliestMonthKey)
    }
}
