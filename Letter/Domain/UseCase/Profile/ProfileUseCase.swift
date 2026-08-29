import Foundation

@MainActor
protocol ProfileUseCase {
    func loadProfile() throws -> UserProfile
    func updateWeekStartsOnMonday(_ enabled: Bool, for profile: UserProfile) throws
    func updateColorScheme(_ colorScheme: AppColorScheme, for profile: UserProfile) throws
    func updateProfile(
        _ profile: UserProfile,
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws
}

@MainActor
final class ImpProfileUseCase: ProfileUseCase {
    private let repository: any HabitRepository

    init(repository: any HabitRepository) {
        self.repository = repository
    }

    func loadProfile() throws -> UserProfile {
        if let profile = try repository.fetchUserProfile() {
            return profile
        }

        let profile = UserProfile()
        repository.addProfile(profile)
        try save()
        return profile
    }

    func updateWeekStartsOnMonday(_ enabled: Bool, for profile: UserProfile) throws {
        profile.weekStartsOnMonday = enabled
        try save()
    }

    func updateColorScheme(_ colorScheme: AppColorScheme, for profile: UserProfile) throws {
        profile.colorScheme = colorScheme
        try save()
    }

    func updateProfile(
        _ profile: UserProfile,
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws {
        profile.displayName = displayName
        profile.avatarOriginalData = avatarOriginalData
        profile.avatarData = avatarData
        try save()
    }

    private func save() throws {
        do {
            try repository.save()
        } catch {
            repository.rollback()
            throw error
        }
    }
}
