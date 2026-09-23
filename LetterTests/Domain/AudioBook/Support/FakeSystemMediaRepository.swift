import Foundation
@testable import Domain

@MainActor
final class FakeSystemMediaRepository: SystemMediaRepository {
    var onPlay: (() -> Void)?
    var onPause: (() -> Void)?
    var onToggle: (() -> Void)?
    var onPreviousChapter: (() -> Void)?
    var onNextChapter: (() -> Void)?
    var onSkip: ((TimeInterval) -> Void)?
    var onSeekToTime: ((TimeInterval) -> Void)?

    var updatedStates: [SystemMediaState] = []
    var clearCount = 0
    var chapterNavigation: [(previousEnabled: Bool, nextEnabled: Bool)] = []

    func update(_ state: SystemMediaState) {
        updatedStates.append(state)
    }

    func clear() {
        clearCount += 1
    }

    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool) {
        chapterNavigation.append((previousEnabled, nextEnabled))
    }
}
