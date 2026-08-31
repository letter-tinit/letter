import Foundation
import Utility

public struct UserProfileSnapshot {
    public let id: UUID
    public let displayName: String
    public let avatarOriginalData: Data?
    public let avatarData: Data?
    public let weekStartsOnMonday: Bool
    public let colorScheme: AppColorScheme
    public init(id: UUID, displayName: String, avatarOriginalData: Data?, avatarData: Data?, weekStartsOnMonday: Bool, colorScheme: AppColorScheme) { self.id = id; self.displayName = displayName; self.avatarOriginalData = avatarOriginalData; self.avatarData = avatarData; self.weekStartsOnMonday = weekStartsOnMonday; self.colorScheme = colorScheme }
}
