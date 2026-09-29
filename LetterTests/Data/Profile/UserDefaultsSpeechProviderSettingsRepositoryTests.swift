import XCTest
@testable import Data
@testable import Domain

final class UserDefaultsSpeechProviderSettingsRepositoryTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUpWithError() throws {
        suiteName = "LetterSpeechProviderSettingsTests.\(UUID().uuidString)"
        defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
    }

    func test_loadProvider_returnsAppleWhenMissingOrInvalid() {
        let repository = makeRepository()

        XCTAssertEqual(repository.loadProvider(), .apple)

        defaults.set("unknown", forKey: "audioBook.speechProvider")

        XCTAssertEqual(repository.loadProvider(), .apple)
    }

    func test_saveProvider_roundTripsStoredProvider() {
        let repository = makeRepository()

        repository.saveProvider(.offline)

        XCTAssertEqual(makeRepository().loadProvider(), .offline)
    }

    func test_appleVoiceID_roundTripsPerLanguage() {
        let repository = makeRepository()

        repository.saveAppleVoiceID("vi-voice", for: .vietnamese)
        repository.saveAppleVoiceID("en-voice", for: .english)

        let reloaded = makeRepository()
        XCTAssertEqual(reloaded.loadAppleVoiceID(for: .vietnamese), "vi-voice")
        XCTAssertEqual(reloaded.loadAppleVoiceID(for: .english), "en-voice")
    }

    func test_offlineModel_roundTripsPerLanguageAndFallsBackForMismatchedLanguage() {
        let repository = makeRepository()

        repository.saveOfflineModel(.vieNeuV3Nano, for: .vietnamese)
        repository.saveOfflineModel(.kokoro82M, for: .english)

        XCTAssertEqual(repository.loadOfflineModel(for: .vietnamese), .vieNeuV3Nano)
        XCTAssertEqual(repository.loadOfflineModel(for: .english), .kokoro82M)

        defaults.set(OfflineSpeechModel.kokoro82M.rawValue, forKey: "audioBook.offlineModel.vietnamese")

        XCTAssertEqual(repository.loadOfflineModel(for: .vietnamese), .vieNeuV3Turbo)
    }

    func test_offlineModel_readsLegacyVietnameseModelWhenNewKeyIsMissing() {
        defaults.set(OfflineSpeechModel.vieNeuV3Nano.rawValue, forKey: "audioBook.offlineVietnameseModel")

        XCTAssertEqual(makeRepository().loadOfflineModel(for: .vietnamese), .vieNeuV3Nano)
    }

    func test_offlineModel_prefersNewLanguageKeyOverLegacyKey() {
        defaults.set(OfflineSpeechModel.vieNeuV3Turbo.rawValue, forKey: "audioBook.offlineVietnameseModel")
        defaults.set(OfflineSpeechModel.vieNeuV3Nano.rawValue, forKey: "audioBook.offlineModel.vietnamese")

        XCTAssertEqual(makeRepository().loadOfflineModel(for: .vietnamese), .vieNeuV3Nano)
    }

    func test_offlineVoice_roundTripsPerModelAndUsesDefaultWhenMissing() {
        let repository = makeRepository()

        XCTAssertEqual(repository.loadOfflineVoice(for: .vieNeuV3Turbo), .ngocLinh)
        XCTAssertEqual(repository.loadOfflineVoice(for: .vieNeuV3Nano), .adam)
        XCTAssertEqual(repository.loadOfflineVoice(for: .kokoro82M), .kokoroHeart)

        repository.saveOfflineVoice(.maiAnh, for: .vieNeuV3Turbo)
        repository.saveOfflineVoice(.kokoroMichael, for: .kokoro82M)

        let reloaded = makeRepository()
        XCTAssertEqual(reloaded.loadOfflineVoice(for: .vieNeuV3Turbo), .maiAnh)
        XCTAssertEqual(reloaded.loadOfflineVoice(for: .kokoro82M), .kokoroMichael)
    }

    func test_offlineVoice_readsLegacyVieNeuVoiceWhenNewKeyIsMissing() {
        defaults.set(OfflineSpeechVoice.thaiSon.rawValue, forKey: "audioBook.vieNeuVoice")

        XCTAssertEqual(makeRepository().loadOfflineVoice(for: .vieNeuV3Turbo), .thaiSon)
    }

    func test_offlineVoice_prefersNewModelKeyOverLegacyKey() {
        defaults.set(OfflineSpeechVoice.thaiSon.rawValue, forKey: "audioBook.vieNeuVoice")
        defaults.set(OfflineSpeechVoice.minhDuc.rawValue, forKey: "audioBook.offlineVoice.vieNeuV3Turbo")

        XCTAssertEqual(makeRepository().loadOfflineVoice(for: .vieNeuV3Turbo), .minhDuc)
    }

    private func makeRepository() -> UserDefaultsSpeechProviderSettingsRepository {
        UserDefaultsSpeechProviderSettingsRepository(defaults: defaults)
    }
}

final class InMemorySpeechProviderSettingsRepositoryTests: XCTestCase {
    func test_repositoryStoresProviderVoicesAndModelsInMemory() {
        let repository = InMemorySpeechProviderSettingsRepository()

        repository.saveProvider(.offline)
        repository.saveAppleVoiceID("voice", for: .english)
        repository.saveOfflineModel(.vieNeuV3Nano, for: .vietnamese)
        repository.saveOfflineVoice(.maiAnh, for: .vieNeuV3Turbo)

        XCTAssertEqual(repository.loadProvider(), .offline)
        XCTAssertEqual(repository.loadAppleVoiceID(for: .english), "voice")
        XCTAssertEqual(repository.loadOfflineModel(for: .vietnamese), .vieNeuV3Nano)
        XCTAssertEqual(repository.loadOfflineVoice(for: .vieNeuV3Turbo), .maiAnh)
    }

    func test_repositoryResolvesDefaultModelAndVoiceWhenMissingOrMismatched() {
        let repository = InMemorySpeechProviderSettingsRepository()

        repository.saveOfflineModel(.kokoro82M, for: .vietnamese)

        XCTAssertEqual(repository.loadOfflineModel(for: .vietnamese), .vieNeuV3Turbo)
        XCTAssertEqual(repository.loadOfflineModel(for: .english), .kokoro82M)
        XCTAssertEqual(repository.loadOfflineVoice(for: .vieNeuV3Nano), .adam)
    }
}
