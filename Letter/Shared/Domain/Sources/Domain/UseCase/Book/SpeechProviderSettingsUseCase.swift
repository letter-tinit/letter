import Foundation

public enum SpeechProvider: String, CaseIterable, Sendable {
    case apple
    case googleCloud
    case offline
}

public enum GoogleCloudVoicePreference: String, CaseIterable, Sendable {
    case femaleOne
    case femaleTwo
    case maleOne
    case maleTwo
}

public enum OfflineVietnameseModel: String, CaseIterable, Sendable {
    case piperVais1000
    case vieNeuV3Turbo
}

public enum VieNeuVoice: String, CaseIterable, Sendable {
    case trucLy = "Trúc Ly"
    case phamTuyen = "Phạm Tuyên"
    case thaiSon = "Thái Sơn"
    case xuanVinh = "Xuân Vĩnh"
    case thanhBinh = "Thanh Bình"
    case minhDuc = "Minh Đức"
    case ngocLinh = "Ngọc Linh"
    case doanTrang = "Đoan Trang"
    case maiAnh = "Mai Anh"
    case thucDoan = "Thục Đoan"
}

public struct SpeechProviderSettings: Equatable, Sendable {
    public let provider: SpeechProvider
    public let hasGoogleCloudAPIKey: Bool
    public let googleCloudVoice: GoogleCloudVoicePreference
    public let offlineVietnameseModel: OfflineVietnameseModel
    public let vieNeuVoice: VieNeuVoice

    public init(
        provider: SpeechProvider,
        hasGoogleCloudAPIKey: Bool,
        googleCloudVoice: GoogleCloudVoicePreference,
        offlineVietnameseModel: OfflineVietnameseModel,
        vieNeuVoice: VieNeuVoice
    ) {
        self.provider = provider
        self.hasGoogleCloudAPIKey = hasGoogleCloudAPIKey
        self.googleCloudVoice = googleCloudVoice
        self.offlineVietnameseModel = offlineVietnameseModel
        self.vieNeuVoice = vieNeuVoice
    }
}

public enum SpeechProviderSettingsError: Error, Equatable {
    case missingGoogleCloudAPIKey
    case credentialStorageFailed
    case offlineModelUnavailable
}

public protocol OfflineSpeechModelPreparing: AnyObject, Sendable {
    func prepare(_ model: OfflineVietnameseModel) async throws
}

public protocol SpeechProviderSettingsRepository: AnyObject, Sendable {
    func loadProvider() -> SpeechProvider
    func saveProvider(_ provider: SpeechProvider)
    func loadGoogleCloudVoice() -> GoogleCloudVoicePreference
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference)
    func loadOfflineVietnameseModel() -> OfflineVietnameseModel
    func saveOfflineVietnameseModel(_ model: OfflineVietnameseModel)
    func loadVieNeuVoice() -> VieNeuVoice
    func saveVieNeuVoice(_ voice: VieNeuVoice)
    func loadGoogleCloudAPIKey() -> String?
    func saveGoogleCloudAPIKey(_ apiKey: String) throws
    func removeGoogleCloudAPIKey() throws
}

public protocol SpeechProviderSettingsUseCase: AnyObject, Sendable {
    func load() -> SpeechProviderSettings
    func save(
        provider: SpeechProvider,
        offlineVietnameseModel: OfflineVietnameseModel,
        newGoogleCloudAPIKey: String?
    ) async throws -> SpeechProviderSettings
    func removeGoogleCloudCredential() throws -> SpeechProviderSettings
    func saveGoogleCloudVoice(_ voice: GoogleCloudVoicePreference) -> SpeechProviderSettings
    func saveVieNeuVoice(_ voice: VieNeuVoice) -> SpeechProviderSettings
}

public final class ImpSpeechProviderSettingsUseCase: SpeechProviderSettingsUseCase {
    private let repository: any SpeechProviderSettingsRepository
    private let offlineSpeech: any OfflineSpeechModelPreparing

    public init(
        repository: any SpeechProviderSettingsRepository,
        offlineSpeech: any OfflineSpeechModelPreparing
    ) {
        self.repository = repository
        self.offlineSpeech = offlineSpeech
    }

    public func load() -> SpeechProviderSettings {
        makeSettings(provider: repository.loadProvider())
    }

    public func save(
        provider: SpeechProvider,
        offlineVietnameseModel: OfflineVietnameseModel,
        newGoogleCloudAPIKey: String?
    ) async throws -> SpeechProviderSettings {
        let apiKey = normalizedAPIKey(newGoogleCloudAPIKey)
        do {
            if let apiKey { try repository.saveGoogleCloudAPIKey(apiKey) }
        } catch {
            throw SpeechProviderSettingsError.credentialStorageFailed
        }
        guard provider != .googleCloud || hasGoogleCloudCredential else {
            throw SpeechProviderSettingsError.missingGoogleCloudAPIKey
        }
        if provider == .offline {
            do {
                try await offlineSpeech.prepare(offlineVietnameseModel)
            } catch {
                throw SpeechProviderSettingsError.offlineModelUnavailable
            }
        }
        repository.saveOfflineVietnameseModel(offlineVietnameseModel)
        repository.saveProvider(provider)
        return makeSettings(provider: provider)
    }

    public func removeGoogleCloudCredential() throws -> SpeechProviderSettings {
        do {
            try repository.removeGoogleCloudAPIKey()
        } catch {
            throw SpeechProviderSettingsError.credentialStorageFailed
        }
        repository.saveProvider(.apple)
        return makeSettings(provider: .apple)
    }

    public func saveGoogleCloudVoice(
        _ voice: GoogleCloudVoicePreference
    ) -> SpeechProviderSettings {
        repository.saveGoogleCloudVoice(voice)
        return makeSettings(provider: repository.loadProvider())
    }

    public func saveVieNeuVoice(
        _ voice: VieNeuVoice
    ) -> SpeechProviderSettings {
        repository.saveVieNeuVoice(voice)
        return makeSettings(provider: repository.loadProvider())
    }

    private var hasGoogleCloudCredential: Bool {
        normalizedAPIKey(repository.loadGoogleCloudAPIKey()) != nil
    }

    private func makeSettings(provider: SpeechProvider) -> SpeechProviderSettings {
        SpeechProviderSettings(
            provider: provider,
            hasGoogleCloudAPIKey: hasGoogleCloudCredential,
            googleCloudVoice: repository.loadGoogleCloudVoice(),
            offlineVietnameseModel: repository.loadOfflineVietnameseModel(),
            vieNeuVoice: repository.loadVieNeuVoice()
        )
    }

    private func normalizedAPIKey(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
