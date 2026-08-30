import Foundation

struct BookChapterSegmenter {
    private let headingPattern = try! NSRegularExpression(
        pattern: #"^\s*(chương|chapter|phần|part)\s+([0-9ivxlcdm]+)(?:\s*[:.\-–—]\s*|\s+).*$"#,
        options: [.caseInsensitive]
    )

    func chapters(from text: String, fallbackTitle: String) -> [BookChapter] {
        let normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        let headingIndexes = lines.indices.filter { isHeading(lines[$0]) }

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

    private func isHeading(_ line: String) -> Bool {
        let range = NSRange(line.startIndex..<line.endIndex, in: line)
        return headingPattern.firstMatch(in: line, range: range) != nil
    }
}
