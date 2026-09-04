import Foundation
import Observation

public enum AudioBookRoute: Hashable {
    case detail(bookID: UUID)
    case player(bookID: UUID, chapterID: UUID)
}

@Observable
public final class AudioBookRouter: AppRouter<AudioBookRoute> {}
