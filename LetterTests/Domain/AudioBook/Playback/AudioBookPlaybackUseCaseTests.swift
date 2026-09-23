import XCTest
@testable import Domain

@MainActor
final class AudioBookPlaybackUseCaseTests: XCTestCase {
    func test_playWithAppleProvider_sendsClampedRequestToAppleEngine() throws {
        let chapter = AudioBookTestFactory.chapter(content: "Hello playback", index: 0)
        let settings = FakeSpeechProviderSettingsRepository()
        settings.provider = .apple
        settings.appleVoiceIDs[.english] = "voice.en"
        let appleEngine = FakeSpeechPlaybackRepository()
        let offlineEngine = FakeSpeechPlaybackRepository()
        let useCase = makeUseCase(
            settings: settings,
            appleEngine: appleEngine,
            offlineEngine: offlineEngine
        )

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 999,
            rate: 9,
            language: .english
        )

        let request = appleEngine.playedRequests.first
        XCTAssertEqual(request?.bookTitle, "Book")
        XCTAssertEqual(request?.chapterID, chapter.id)
        XCTAssertEqual(request?.characterOffset, chapter.characterCount)
        XCTAssertEqual(request?.rateMultiplier, 3)
        XCTAssertEqual(request?.selection, .apple(voiceID: "voice.en"))
        XCTAssertTrue(offlineEngine.playedRequests.isEmpty)
    }

    func test_playWithOfflineProvider_routesToOfflineEngineWithDefaultVoice() throws {
        let chapter = AudioBookTestFactory.chapter()
        let settings = FakeSpeechProviderSettingsRepository()
        settings.provider = .offline
        settings.offlineModels[.vietnamese] = .vieNeuV3Nano
        let appleEngine = FakeSpeechPlaybackRepository()
        let offlineEngine = FakeSpeechPlaybackRepository()
        let useCase = makeUseCase(
            settings: settings,
            appleEngine: appleEngine,
            offlineEngine: offlineEngine
        )

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 0,
            rate: 1,
            language: .vietnamese
        )

        XCTAssertEqual(
            offlineEngine.playedRequests.first?.selection,
            .offline(model: .vieNeuV3Nano, voice: OfflineSpeechModel.vieNeuV3Nano.defaultVoice)
        )
        XCTAssertTrue(appleEngine.playedRequests.isEmpty)
    }

    func test_playWithMissingOfflineModel_reportsFailureAndFallsBackToApple() throws {
        let chapter = AudioBookTestFactory.chapter()
        let settings = FakeSpeechProviderSettingsRepository()
        settings.provider = .offline
        settings.appleVoiceIDs[.english] = "fallback"
        let appleEngine = FakeSpeechPlaybackRepository()
        let useCase = makeUseCase(settings: settings, appleEngine: appleEngine)
        var failures: [SpeechPlaybackFailure] = []
        useCase.onFailure = { failures.append($0) }

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 0,
            rate: 1,
            language: .english
        )

        XCTAssertEqual(failures, [.offlineUnavailable])
        XCTAssertEqual(appleEngine.playedRequests.first?.selection, .apple(voiceID: "fallback"))
    }

    func test_offlineFailureFallsBackToAppleAtCurrentOffset() throws {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let settings = FakeSpeechProviderSettingsRepository()
        settings.provider = .offline
        settings.offlineModels[.vietnamese] = .vieNeuV3Nano
        let appleEngine = FakeSpeechPlaybackRepository()
        let offlineEngine = FakeSpeechPlaybackRepository()
        let useCase = makeUseCase(
            settings: settings,
            appleEngine: appleEngine,
            offlineEngine: offlineEngine
        )

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 10,
            rate: 1,
            language: .vietnamese
        )
        offlineEngine.onProgress?(
            SpeechPlaybackProgress(
                chapterID: chapter.id,
                characterOffset: 22,
                totalCharacterCount: chapter.characterCount
            )
        )
        offlineEngine.onFailure?(.unavailable)

        XCTAssertEqual(appleEngine.playedRequests.first?.characterOffset, 22)
        XCTAssertEqual(appleEngine.playedRequests.first?.selection, .apple(voiceID: nil))
    }

    func test_engineProgressAndStatePublishSystemMedia() throws {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 28), index: 0)
        let appleEngine = FakeSpeechPlaybackRepository()
        let media = FakeSystemMediaRepository()
        let useCase = makeUseCase(appleEngine: appleEngine, media: media)
        var progressEvents: [SpeechPlaybackProgress] = []
        useCase.onProgress = { progressEvents.append($0) }

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 0,
            rate: 1,
            language: .vietnamese
        )
        appleEngine.onStateChanged?(.playing)
        let progress = SpeechPlaybackProgress(
            chapterID: chapter.id,
            characterOffset: 14,
            totalCharacterCount: chapter.characterCount
        )
        appleEngine.onProgress?(progress)

        XCTAssertEqual(progressEvents, [progress])
        XCTAssertEqual(media.updatedStates.last?.title, chapter.title)
        XCTAssertEqual(media.updatedStates.last?.bookTitle, "Book")
        XCTAssertEqual(media.updatedStates.last?.playbackState, .playing)
        XCTAssertEqual(media.updatedStates.last?.elapsedTime, 1)
    }

    func test_mediaCommandsForwardToActiveEngineAndChapterCallbacks() throws {
        let chapter = AudioBookTestFactory.chapter()
        let appleEngine = FakeSpeechPlaybackRepository()
        let media = FakeSystemMediaRepository()
        let useCase = makeUseCase(appleEngine: appleEngine, media: media)
        var previousCount = 0
        var nextCount = 0
        useCase.onPreviousChapterRequested = { previousCount += 1 }
        useCase.onNextChapterRequested = { nextCount += 1 }

        try useCase.play(
            bookTitle: "Book",
            chapter: chapter,
            from: 0,
            rate: 1,
            language: .vietnamese
        )
        media.onPlay?()
        media.onPause?()
        media.onSkip?(15)
        media.onPreviousChapter?()
        media.onNextChapter?()

        XCTAssertEqual(appleEngine.resumeCount, 1)
        XCTAssertEqual(appleEngine.pauseCount, 1)
        XCTAssertEqual(appleEngine.skippedSeconds, [15])
        XCTAssertEqual(previousCount, 1)
        XCTAssertEqual(nextCount, 1)
    }

    func test_normalizedRateAndOffsetsClampValues() {
        let chapter = AudioBookTestFactory.chapter(content: String(repeating: "a", count: 100), index: 0)
        let useCase = makeUseCase()

        XCTAssertEqual(useCase.normalizedRate(0.1), 0.5)
        XCTAssertEqual(useCase.normalizedRate(1.13), 1.25)
        XCTAssertEqual(useCase.normalizedRate(9), 3)
        XCTAssertEqual(useCase.characterOffset(for: -1, in: chapter), 0)
        XCTAssertEqual(useCase.characterOffset(for: 2, in: chapter), 100)
    }

    private func makeUseCase(
        settings: FakeSpeechProviderSettingsRepository = FakeSpeechProviderSettingsRepository(),
        appleEngine: FakeSpeechPlaybackRepository? = nil,
        offlineEngine: FakeSpeechPlaybackRepository? = nil,
        media: FakeSystemMediaRepository? = nil
    ) -> ImpAudioBookPlaybackUseCase {
        ImpAudioBookPlaybackUseCase(
            settings: settings,
            media: media ?? FakeSystemMediaRepository(),
            appleEngine: appleEngine ?? FakeSpeechPlaybackRepository(),
            offlineEngine: offlineEngine ?? FakeSpeechPlaybackRepository()
        )
    }
}
