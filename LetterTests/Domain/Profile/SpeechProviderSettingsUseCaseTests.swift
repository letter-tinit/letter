import XCTest
@testable import Domain

final class SpeechProviderSettingsUseCaseTests: XCTestCase {
    func test_load_collectsProviderVoicesAndModels() {
        let repository = FakeSpeechProviderSettingsRepository()
        repository.provider = .offline
        repository.appleVoiceIDs[.english] = "voice.en"
        repository.offlineModels[.vietnamese] = .vieNeuV3Nano
        repository.offlineVoices[.vieNeuV3Nano] = .maiAnh
        let useCase = ImpSpeechProviderSettingsUseCase(repository: repository)

        let settings = useCase.load()

        XCTAssertEqual(settings.provider, .offline)
        XCTAssertEqual(settings.appleVoiceID(for: .english), "voice.en")
        XCTAssertEqual(settings.offlineModel(for: .vietnamese), .vieNeuV3Nano)
        XCTAssertEqual(settings.offlineVoice(for: .vieNeuV3Nano), .maiAnh)
    }

    func test_saveProvider_persistsOnlyLanguageMatchingOfflineModels() {
        let repository = FakeSpeechProviderSettingsRepository()
        let useCase = ImpSpeechProviderSettingsUseCase(repository: repository)

        let settings = useCase.save(
            provider: .offline,
            offlineModels: [
                .vietnamese: .vieNeuV3Turbo,
                .english: .vieNeuV3Nano
            ]
        )

        XCTAssertEqual(repository.provider, .offline)
        XCTAssertEqual(repository.offlineModels[.vietnamese], .vieNeuV3Turbo)
        XCTAssertNil(repository.offlineModels[.english])
        XCTAssertEqual(settings.provider, .offline)
        XCTAssertEqual(settings.offlineModel(for: .vietnamese), .vieNeuV3Turbo)
        XCTAssertEqual(settings.offlineModel(for: .english), .kokoro82M)
    }

    func test_saveAppleVoiceAndOfflineVoice_returnUpdatedSettingsWithoutChangingProvider() {
        let repository = FakeSpeechProviderSettingsRepository()
        repository.provider = .offline
        let useCase = ImpSpeechProviderSettingsUseCase(repository: repository)

        let appleSettings = useCase.saveAppleVoiceID("voice.vi", for: .vietnamese)
        let offlineSettings = useCase.saveOfflineVoice(.kokoroMichael, for: .kokoro82M)

        XCTAssertEqual(appleSettings.provider, .offline)
        XCTAssertEqual(appleSettings.appleVoiceID(for: .vietnamese), "voice.vi")
        XCTAssertEqual(offlineSettings.provider, .offline)
        XCTAssertEqual(offlineSettings.offlineVoice(for: .kokoro82M), .kokoroMichael)
    }

    func test_settingsResolveMissingOrMismatchedOfflineModelToLanguageDefault() {
        let settings = SpeechProviderSettings(
            provider: .offline,
            appleVoiceIDs: [:],
            offlineModels: [.english: .vieNeuV3Nano],
            offlineVoices: [:]
        )

        XCTAssertEqual(settings.offlineModel(for: .english), .kokoro82M)
        XCTAssertEqual(settings.offlineModel(for: .vietnamese), .vieNeuV3Turbo)
        XCTAssertEqual(settings.offlineVoice(for: .vieNeuV3Nano), .adam)
    }
}
