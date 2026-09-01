import Foundation

struct SpeechTextChunker {
    private let minimumChunkLength = 20

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
        mergeShortTail(in: &result)
        return result
    }

    private func chunkLength(source: NSString, location: Int, limit: Int) -> Int {
        let remaining = source.length - location
        let requested = min(max(limit, 1), remaining)
        let proposed = source.rangeOfComposedCharacterSequences(
            for: NSRange(location: location, length: requested)
        ).length
        guard proposed < remaining else { return proposed }

        let searchRange = NSRange(location: location, length: proposed)
        if let end = lastBoundaryEnd(
            in: source,
            range: searchRange,
            characters: CharacterSet(charactersIn: "\n\r.!?…"),
            minimumOffset: minimumChunkLength,
            requiresFollowingWhitespace: true
        ) {
            return end - location
        }

        if let end = lastBoundaryEnd(
            in: source,
            range: searchRange,
            characters: CharacterSet(charactersIn: ",;:—–"),
            minimumOffset: proposed / 2,
            requiresFollowingWhitespace: false
        ) {
            return end - location
        }

        let whitespace = source.rangeOfCharacter(
            from: .whitespacesAndNewlines,
            options: .backwards,
            range: searchRange
        )
        if whitespace.location != NSNotFound,
           whitespace.location - location >= proposed * 2 / 3 {
            return whitespace.location + whitespace.length - location
        }
        return proposed
    }

    private func lastBoundaryEnd(
        in source: NSString,
        range: NSRange,
        characters: CharacterSet,
        minimumOffset: Int,
        requiresFollowingWhitespace: Bool
    ) -> Int? {
        var searchRange = range
        while searchRange.length > 0 {
            let boundary = source.rangeOfCharacter(
                from: characters,
                options: .backwards,
                range: searchRange
            )
            guard boundary.location != NSNotFound else { return nil }
            let end = extendedBoundaryEnd(
                in: source,
                from: boundary.location + boundary.length,
                limit: NSMaxRange(range)
            )
            let boundaryCharacter = source.character(at: boundary.location)
            let isLineBreak = boundaryCharacter == 10 || boundaryCharacter == 13
            let hasNaturalFollower = isLineBreak
                || end >= source.length
                || contains(
                    source.character(at: end),
                    in: .whitespacesAndNewlines
                )
            if boundary.location - range.location >= minimumOffset,
               (!requiresFollowingWhitespace || hasNaturalFollower) {
                return end
            }
            searchRange.length = boundary.location - range.location
        }
        return nil
    }

    private func extendedBoundaryEnd(
        in source: NSString,
        from start: Int,
        limit: Int
    ) -> Int {
        let trailing = CharacterSet(charactersIn: ".!?…\"'”’»)]}")
        var end = start
        while end < limit,
              contains(source.character(at: end), in: trailing) {
            end += 1
        }
        return end
    }

    private func contains(_ codeUnit: unichar, in set: CharacterSet) -> Bool {
        guard let scalar = UnicodeScalar(UInt32(codeUnit)) else { return false }
        return set.contains(scalar)
    }

    private func mergeShortTail(in chunks: inout [Chunk]) {
        guard chunks.count > 1,
              let tail = chunks.last,
              tail.utf16Length < minimumChunkLength else { return }
        let previous = chunks[chunks.count - 2]
        chunks.removeLast(2)
        chunks.append(
            Chunk(
                text: previous.text + tail.text,
                utf16Offset: previous.utf16Offset
            )
        )
    }
}
