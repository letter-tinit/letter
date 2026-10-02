import Foundation
import Observation

public enum AudioBookRoute: Hashable {
    case bookmarks(bookID: UUID)
    case detail(bookID: UUID)
    case player(bookID: UUID, chapterID: UUID)
}

@Observable
public final class AudioBookRouter: AppRouter<AudioBookRoute> {}
