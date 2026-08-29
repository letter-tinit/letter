import Foundation

@MainActor
protocol ProfileUseCase {
    func loadProfile() throws -> UserProfileSnapshot
    func updateWeekStartsOnMonday(_ enabled: Bool) throws -> UserProfileSnapshot
    func updateColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot
    func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws -> UserProfileSnapshot
}

enum ProfileUseCaseError: Error {
    case profileNotFound
}

@MainActor
final class ImpProfileUseCase: ProfileUseCase {
    private let repository: any HabitRepository

    init(repository: any HabitRepository) {
        self.repository = repository
    }

    func loadProfile() throws -> UserProfileSnapshot {
        if let profile = try repository.fetchUserProfile() { return profile }
        return try repository.createDefaultUserProfile()
    }

    func updateWeekStartsOnMonday(_ enabled: Bool) throws -> UserProfileSnapshot {
        guard let profile = try repository.updateProfileWeekStart(enabled) else {
            throw ProfileUseCaseError.profileNotFound
        }
        return profile
    }

    func updateColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot {
        guard let profile = try repository.updateProfileColorScheme(colorScheme) else {
            throw ProfileUseCaseError.profileNotFound
        }
        return profile
    }

    func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws -> UserProfileSnapshot {
        guard let profile = try repository.updateProfile(
            displayName: displayName,
            avatarOriginalData: avatarOriginalData,
            avatarData: avatarData
        ) else {
            throw ProfileUseCaseError.profileNotFound
        }
        return profile
    }
}
