import Foundation
import Domain

public final class UserDefaultsGoogleCloudSpeechUsageRepository: GoogleCloudSpeechUsageRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, calendar: Calendar? = nil) {
        self.defaults = defaults
        self.calendar = calendar ?? Self.googleCloudBillingCalendar
    }

    public func currentUsage() -> GoogleCloudSpeechUsage {
        lock.withLock {
            GoogleCloudSpeechUsage(characterCount: defaults.integer(forKey: currentKey))
        }
    }

    public func reserve(characterCount: Int) -> Bool {
        guard characterCount > 0 else { return false }
        return lock.withLock {
            let key = currentKey
            let current = defaults.integer(forKey: key)
            guard current + characterCount <= GoogleCloudSpeechUsage.freeOnlyCharacterLimit else {
                return false
            }
            defaults.set(current + characterCount, forKey: key)
            return true
        }
    }

    private var currentKey: String {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return "audioBook.googleCloudUsage.\(components.year ?? 0)-\(components.month ?? 0)"
    }

    private static var googleCloudBillingCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        if let timeZone = TimeZone(identifier: "America/Los_Angeles") {
            calendar.timeZone = timeZone
        }
        return calendar
    }
}

public final class InMemoryGoogleCloudSpeechUsageRepository: GoogleCloudSpeechUsageRepository, @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    public init() {}

    public func currentUsage() -> GoogleCloudSpeechUsage {
        lock.withLock { GoogleCloudSpeechUsage(characterCount: count) }
    }

    public func reserve(characterCount: Int) -> Bool {
        guard characterCount > 0 else { return false }
        return lock.withLock {
            guard count + characterCount <= GoogleCloudSpeechUsage.freeOnlyCharacterLimit else {
                return false
            }
            count += characterCount
            return true
        }
    }

}
