import Foundation

public struct GoogleCloudSpeechUsage: Equatable, Sendable {
    public static let freeOnlyCharacterLimit = 3_950_000

    public let characterCount: Int
    public let freeCharacterLimit: Int

    public init(
        characterCount: Int,
        freeCharacterLimit: Int = Self.freeOnlyCharacterLimit
    ) {
        self.characterCount = characterCount
        self.freeCharacterLimit = freeCharacterLimit
    }

    public var remainingFreeCharacters: Int {
        max(freeCharacterLimit - characterCount, 0)
    }
}

public protocol GoogleCloudSpeechUsageUseCase: AnyObject, Sendable {
    func loadCurrentUsage() -> GoogleCloudSpeechUsage
}

public final class ImpGoogleCloudSpeechUsageUseCase: GoogleCloudSpeechUsageUseCase {
    private let repository: any GoogleCloudSpeechUsageRepository

    public init(repository: any GoogleCloudSpeechUsageRepository) {
        self.repository = repository
    }

    public func loadCurrentUsage() -> GoogleCloudSpeechUsage {
        repository.currentUsage()
    }
}
