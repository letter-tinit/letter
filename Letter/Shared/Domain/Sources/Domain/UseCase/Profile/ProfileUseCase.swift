import Foundation
import Utility

@MainActor
public protocol ProfileUseCase {
    func loadProfile() throws -> UserProfileSnapshot
    func updateWeekStartsOnMonday(_ enabled: Bool) throws -> UserProfileSnapshot
    func updateColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot
    func updateProfile(
        displayName: String,
        avatarOriginalData: Data?,
        avatarData: Data?
    ) throws -> UserProfileSnapshot
    func exportBackup() throws -> BackupFile
    func inspectBackup(at url: URL) throws -> BackupImport
    func restoreBackup(_ data: Data) throws
    func clearAllData() throws
}

public enum ProfileUseCaseError: Error {
    case profileNotFound
}

@MainActor
public final class ImpProfileUseCase: ProfileUseCase {
    private let repository: any HabitRepository
    private let backupRepository: any BackupRepository

    public init(repository: any HabitRepository, backupRepository: any BackupRepository) {
        self.repository = repository
        self.backupRepository = backupRepository
    }

    public func loadProfile() throws -> UserProfileSnapshot {
        if let profile = try repository.fetchUserProfile() { return profile }
        return try repository.createDefaultUserProfile()
    }

    public func updateWeekStartsOnMonday(_ enabled: Bool) throws -> UserProfileSnapshot {
        guard let profile = try repository.updateProfileWeekStart(enabled) else {
            throw ProfileUseCaseError.profileNotFound
        }
        return profile
    }

    public func updateColorScheme(_ colorScheme: AppColorScheme) throws -> UserProfileSnapshot {
        guard let profile = try repository.updateProfileColorScheme(colorScheme) else {
            throw ProfileUseCaseError.profileNotFound
        }
        return profile
    }

    public func updateProfile(
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

    public func exportBackup() throws -> BackupFile {
        try backupRepository.exportBackup()
    }

    public func inspectBackup(at url: URL) throws -> BackupImport {
        try backupRepository.inspectBackup(at: url)
    }

    public func restoreBackup(_ data: Data) throws {
        try backupRepository.restoreBackup(data)
    }

    public func clearAllData() throws {
        try backupRepository.clearAllData()
    }
}
