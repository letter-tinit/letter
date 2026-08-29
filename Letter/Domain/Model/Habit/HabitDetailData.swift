import Foundation

struct HabitDetailData {
    let habit: HabitSnapshot
    let previousVersionNumber: Int?
    let nextVersionNumber: Int?
    let seriesHabitCount: Int
}

enum HabitDetailError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}
