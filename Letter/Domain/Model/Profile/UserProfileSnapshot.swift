import Foundation

struct UserProfileSnapshot {
    let id: UUID
    let displayName: String
    let avatarOriginalData: Data?
    let avatarData: Data?
    let weekStartsOnMonday: Bool
    let colorScheme: AppColorScheme
}
