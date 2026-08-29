import Foundation

enum HabitFrequency: String, Codable {
    case daily
    case weekday
    case weekend
    case custom
}

enum GoalType: String, Codable {
    case count
    case todo
}

enum HabitEntryStatus: String, Codable {
    case active
    case skipped
}
