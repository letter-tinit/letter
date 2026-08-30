import Foundation

struct BookPlaybackCheckpoint: Codable, Sendable, Equatable {
    let position: BookReadingPosition
    let furthestPosition: BookReadingPosition?
    let rateMultiplier: Double

    init(
        position: BookReadingPosition,
        rateMultiplier: Double,
        furthestPosition: BookReadingPosition? = nil
    ) {
        self.position = position
        self.furthestPosition = furthestPosition
        self.rateMultiplier = rateMultiplier
    }
}
