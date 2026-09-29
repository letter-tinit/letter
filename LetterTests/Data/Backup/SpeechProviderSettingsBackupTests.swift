import XCTest
@testable import Data
@testable import Domain

final class SpeechProviderSettingsBackupTests: XCTestCase {
    func test_init_capturesRepositorySettings() {
        let repository = InMemorySpeechProviderSettingsRepository()
        repository.saveProvider(.offline)
        repository.saveAppleVoiceID("vi-voice", for: .vietnamese)
        repository.saveAppleVoiceID("en-voice", for: .english)
        repository.saveOfflineModel(.vieNeuV3Nano, for: .vietnamese)
        repository.saveOfflineModel(.kokoro82M, for: .english)
        repository.saveOfflineVoice(.maiAnh, for: .vieNeuV3Turbo)
        repository.saveOfflineVoice(.kokoroMichael, for: .kokoro82M)

        let backup = SpeechProviderSettingsBackup(repository: repository)

        XCTAssertEqual(backup.provider, SpeechProvider.offline.rawValue)
        XCTAssertEqual(backup.appleVoiceIDs[BookLanguage.vietnamese.rawValue], "vi-voice")
        XCTAssertEqual(backup.appleVoiceIDs[BookLanguage.english.rawValue], "en-voice")
        XCTAssertEqual(backup.offlineModels[BookLanguage.vietnamese.rawValue], OfflineSpeechModel.vieNeuV3Nano.rawValue)
        XCTAssertEqual(backup.offlineModels[BookLanguage.english.rawValue], OfflineSpeechModel.kokoro82M.rawValue)
        XCTAssertEqual(backup.offlineVoices[OfflineSpeechModel.vieNeuV3Turbo.rawValue], OfflineSpeechVoice.maiAnh.rawValue)
        XCTAssertEqual(backup.offlineVoices[OfflineSpeechModel.kokoro82M.rawValue], OfflineSpeechVoice.kokoroMichael.rawValue)
    }

    func test_restore_appliesValidSettingsAndIgnoresInvalidValues() throws {
        let data = Data("""
        {
          "provider": "offline",
          "appleVoiceIDs": {
            "vietnamese": "vi-voice"
          },
          "offlineModels": {
            "vietnamese": "\(OfflineSpeechModel.kokoro82M.rawValue)",
            "english": "\(OfflineSpeechModel.kokoro82M.rawValue)"
          },
          "offlineVoices": {
            "\(OfflineSpeechModel.vieNeuV3Turbo.rawValue)": "\(OfflineSpeechVoice.maiAnh.rawValue)",
            "\(OfflineSpeechModel.kokoro82M.rawValue)": "missing-voice"
          }
        }
        """.utf8)
        let backup = try JSONDecoder().decode(SpeechProviderSettingsBackup.self, from: data)
        let repository = InMemorySpeechProviderSettingsRepository()

        backup.restore(to: repository)

        XCTAssertEqual(repository.loadProvider(), .offline)
        XCTAssertEqual(repository.loadAppleVoiceID(for: .vietnamese), "vi-voice")
        XCTAssertEqual(repository.loadOfflineModel(for: .vietnamese), .vieNeuV3Turbo)
        XCTAssertEqual(repository.loadOfflineModel(for: .english), .kokoro82M)
        XCTAssertEqual(repository.loadOfflineVoice(for: .vieNeuV3Turbo), .maiAnh)
        XCTAssertEqual(repository.loadOfflineVoice(for: .kokoro82M), OfflineSpeechVoice(rawValue: "missing-voice"))
    }

    func test_restore_defaultsInvalidProviderToApple() throws {
        let data = Data("""
        {
          "provider": "invalid",
          "appleVoiceIDs": {},
          "offlineModels": {},
          "offlineVoices": {}
        }
        """.utf8)
        let backup = try JSONDecoder().decode(SpeechProviderSettingsBackup.self, from: data)
        let repository = InMemorySpeechProviderSettingsRepository()
        repository.saveProvider(.offline)

        backup.restore(to: repository)

        XCTAssertEqual(repository.loadProvider(), .apple)
    }
}
