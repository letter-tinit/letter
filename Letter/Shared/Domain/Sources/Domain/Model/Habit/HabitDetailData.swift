import Foundation
import Utility

public struct HabitDetailData {
    public let habit: HabitSnapshot
    public let previousVersionNumber: Int?
    public let nextVersionNumber: Int?
    public let seriesHabitCount: Int
}

public enum HabitDetailError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}
