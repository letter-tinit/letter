import Foundation

struct SpeechTextChunker {
    struct Chunk: Sendable {
        let text: String
        let utf16Offset: Int

        var utf16Length: Int { text.utf16.count }
    }

    func chunks(text: String, startingAt offset: Int, maximumLength: Int) -> [Chunk] {
        let source = text as NSString
        var location = min(max(offset, 0), source.length)
        var result: [Chunk] = []
        while location < source.length {
            let length = chunkLength(source: source, location: location, limit: maximumLength)
            let range = NSRange(location: location, length: length)
            result.append(Chunk(text: source.substring(with: range), utf16Offset: location))
            location += length
        }
        return result
    }

    private func chunkLength(source: NSString, location: Int, limit: Int) -> Int {
        let remaining = source.length - location
        let proposed = min(max(limit, 1), remaining)
        guard proposed < remaining else { return proposed }
        let candidate = source.substring(
            with: NSRange(location: location, length: proposed)
        ) as NSString
        let boundary = candidate.rangeOfCharacter(
            from: CharacterSet(charactersIn: "\n.!?"),
            options: .backwards
        )
        guard boundary.location != NSNotFound, boundary.location > proposed / 2 else {
            return proposed
        }
        return boundary.location + boundary.length
    }
}
