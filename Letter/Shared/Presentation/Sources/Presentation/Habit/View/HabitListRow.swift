import Foundation

/// Replaces the native List row when its sorting status changes, clearing
/// transient swipe state without rebuilding the list or unrelated rows.
struct HabitListRow: Identifiable {
    let model: HabitItemView.Model

    var id: ID {
        ID(habitID: model.id, completed: model.entryIsCompleted, skipped: model.isSkipped)
    }

    struct ID: Hashable {
        let habitID: UUID
        let completed: Bool
        let skipped: Bool
    }
}
