import Foundation

@MainActor
public protocol SystemMediaRepository: AnyObject {
    var onPlay: (() -> Void)? { get set }
    var onPause: (() -> Void)? { get set }
    var onToggle: (() -> Void)? { get set }
    var onPreviousChapter: (() -> Void)? { get set }
    var onNextChapter: (() -> Void)? { get set }
    var onSkip: ((TimeInterval) -> Void)? { get set }
    var onSeekToTime: ((TimeInterval) -> Void)? { get set }

    func update(_ state: SystemMediaState)
    func clear()
    func setChapterNavigation(previousEnabled: Bool, nextEnabled: Bool)
}
