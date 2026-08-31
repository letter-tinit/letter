import Foundation
import Domain

public final class UserDefaultsGoogleCloudSpeechUsageRepository: GoogleCloudSpeechUsageRepository, @unchecked Sendable {
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let lock = NSLock()

    public init(defaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar
    }

    public func currentUsage() -> GoogleCloudSpeechUsage {
        lock.withLock {
            GoogleCloudSpeechUsage(characterCount: defaults.integer(forKey: currentKey))
        }
    }

    public func recordSuccessfulSynthesis(characterCount: Int) {
        guard characterCount > 0 else { return }
        lock.withLock {
            defaults.set(defaults.integer(forKey: currentKey) + characterCount, forKey: currentKey)
        }
    }

    private var currentKey: String {
        let components = calendar.dateComponents([.year, .month], from: Date())
        return "audioBook.googleCloudUsage.\(components.year ?? 0)-\(components.month ?? 0)"
    }
}
