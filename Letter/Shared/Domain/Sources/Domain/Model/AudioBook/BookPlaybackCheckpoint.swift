import Foundation
import Utility

public struct BookPlaybackCheckpoint: Codable, Sendable, Equatable {
    public let position: BookReadingPosition
    public let furthestPosition: BookReadingPosition?
    public let rateMultiplier: Double

    public init(
        position: BookReadingPosition,
        rateMultiplier: Double,
        furthestPosition: BookReadingPosition? = nil
    ) {
        self.position = position
        self.furthestPosition = furthestPosition
        self.rateMultiplier = rateMultiplier
    }
}
