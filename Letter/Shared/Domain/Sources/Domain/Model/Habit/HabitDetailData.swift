import Foundation
import Utility

public struct HabitDetailData {
    public let habit: HabitSnapshot
}

public enum HabitDetailError: Error {
    case habitNotFound
    case persistenceFailed(Error)
}
