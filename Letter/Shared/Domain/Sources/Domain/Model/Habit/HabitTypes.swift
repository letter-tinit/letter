import Foundation
import Utility

public enum HabitFrequency: String, Codable {
    case daily
    case weekday
    case weekend
    case custom
}

public enum GoalType: String, Codable {
    case count
    case todo
}

public enum HabitEntryStatus: String, Codable {
    case active
    case skipped
}
