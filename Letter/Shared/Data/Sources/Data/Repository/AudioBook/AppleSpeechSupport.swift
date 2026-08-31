import AVFoundation
import Foundation
import Domain
import Core
import Utility

public struct SpeechTextChunker {
    public struct Chunk {
        public let text: String
        public let utf16Offset: Int

        public init(text: String, utf16Offset: Int) {
            self.text = text
            self.utf16Offset = utf16Offset
        }
    }

    public func chunks(text: String, startingAt offset: Int, maximumLength: Int) -> [Chunk] {
        let source = text as NSString
        var location = min(max(offset, 0), source.length)
        var result: [Chunk] = []
        while location < source.length {
            let remaining = source.length - location
            var length = min(maximumLength, remaining)
            if length < remaining {
                let candidate = source.substring(
                    with: NSRange(location: location, length: length)
                ) as NSString
                let boundary = candidate.rangeOfCharacter(
                    from: CharacterSet(charactersIn: "\n.!?"),
                    options: .backwards
                )
                if boundary.location != NSNotFound, boundary.location > maximumLength / 2 {
                    length = boundary.location + boundary.length
                }
            }
            let range = NSRange(location: location, length: length)
            result.append(Chunk(text: source.substring(with: range), utf16Offset: location))
            location += length
        }
        return result
    }
}

public func appleSpeechRate(multiplier: Double) -> Float {
    let proposed: Float
    if multiplier <= 1 {
        proposed = AVSpeechUtteranceDefaultSpeechRate * Float(multiplier)
    } else {
        let normalized = Float((multiplier - 1) / 2)
        proposed = AVSpeechUtteranceDefaultSpeechRate
            + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate) * normalized
    }
    return min(max(proposed, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
}
