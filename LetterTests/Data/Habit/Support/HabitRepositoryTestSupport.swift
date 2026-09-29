import SwiftData
@testable import Data

@MainActor
enum HabitRepositoryTestSupport {
    static func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Habit.self,
            HabitEntry.self,
            HabitReminder.self,
            UserProfile.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
