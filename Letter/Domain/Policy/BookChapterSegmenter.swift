import Foundation

struct BookChapterSegmenter {
    private struct HeadingCandidate {
        let lineIndex: Int
        let key: String
    }

    private let headingPattern = try! NSRegularExpression(
        pattern: #"^\s*(chương|chapter|phần|part)\s+([0-9ivxlcdm]+)\b(?:\s*[:.\-–—]\s*.*|\s+.*)?\s*$"#,
        options: [.caseInsensitive]
    )

    func chapters(from text: String, fallbackTitle: String) -> [BookChapter] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        let candidates = lines.indices.compactMap { headingCandidate(line: lines[$0], index: $0) }
        let headingIndexes = playableCandidates(from: candidates).map(\.lineIndex)

        guard !headingIndexes.isEmpty else {
            let content = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
            return content.isEmpty ? [] : [BookChapter(title: fallbackTitle, content: content, index: 0)]
        }

        var chapters: [BookChapter] = []
        let preface = lines[..<headingIndexes[0]]
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if !preface.isEmpty {
            chapters.append(BookChapter(title: fallbackTitle, content: preface, index: 0))
        }
        for (position, headingIndex) in headingIndexes.enumerated() {
            let endIndex = position + 1 < headingIndexes.count ? headingIndexes[position + 1] : lines.endIndex
            let title = lines[headingIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let content = lines[headingIndex..<endIndex]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            chapters.append(BookChapter(title: title, content: content, index: chapters.count))
        }
        return chapters
    }

    private func headingCandidate(line: String, index: Int) -> HeadingCandidate? {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        guard let match = headingPattern.firstMatch(in: line, range: range),
              let kindRange = Range(match.range(at: 1), in: line),
              let numberRange = Range(match.range(at: 2), in: line) else { return nil }
        let kind = line[kindRange].folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
        return HeadingCandidate(
            lineIndex: index,
            key: "\(kind.lowercased())-\(line[numberRange].lowercased())"
        )
    }

    private func playableCandidates(from candidates: [HeadingCandidate]) -> [HeadingCandidate] {
        let withoutTOC = removingDenseTableOfContents(from: candidates)
        var result: [HeadingCandidate] = []
        for candidate in withoutTOC where result.last?.key != candidate.key {
            result.append(candidate)
        }
        return result
    }

    private func removingDenseTableOfContents(
        from candidates: [HeadingCandidate]
    ) -> ArraySlice<HeadingCandidate> {
        guard candidates.count >= 6 else { return candidates[...] }
        for restartIndex in 3..<(candidates.count - 2) {
            let prefix = candidates[..<restartIndex]
            let following = candidates[restartIndex...min(restartIndex + 2, candidates.count - 1)]
            let prefixKeys = Set(prefix.map(\.key))
            guard prefixKeys.count >= 3,
                  following.allSatisfy({ prefixKeys.contains($0.key) }),
                  isDense(prefix) else { continue }
            return candidates[restartIndex...]
        }
        return candidates[...]
    }

    private func isDense(_ candidates: ArraySlice<HeadingCandidate>) -> Bool {
        guard let first = candidates.first, let last = candidates.last else { return false }
        return last.lineIndex - first.lineIndex <= candidates.count * 8
    }
}
