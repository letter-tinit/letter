import Foundation

struct BookLanguageDetector {
    private let vietnameseWords: Set<String> = [
        "các", "cho", "của", "được", "không", "là", "một", "những", "trong", "và", "với"
    ]
    private let englishWords: Set<String> = [
        "and", "are", "for", "from", "have", "not", "that", "the", "this", "was", "with"
    ]
    private let vietnameseCharacters = CharacterSet(
        charactersIn: "ăâđêôơưáàảãạấầẩẫậắằẳẵặéèẻẽẹếềểễệíìỉĩịóòỏõọốồổỗộớờởỡợúùủũụứừửữựýỳỷỹỵ"
    )

    func detect(chapters: [BookChapter]) -> BookLanguage {
        let sample = sampleText(from: chapters).lowercased()
        let words = sample.split { !$0.isLetter }.map(String.init)
        let vietnameseWordScore = words.reduce(0) { $0 + (vietnameseWords.contains($1) ? 1 : 0) }
        let englishWordScore = words.reduce(0) { $0 + (englishWords.contains($1) ? 1 : 0) }
        let diacriticScore = sample.unicodeScalars.reduce(0) {
            $0 + (vietnameseCharacters.contains($1) ? 2 : 0)
        }
        return englishWordScore > vietnameseWordScore + diacriticScore ? .english : .vietnamese
    }

    private func sampleText(from chapters: [BookChapter]) -> String {
        var remaining = 100_000
        var parts: [String] = []
        for chapter in chapters where remaining > 0 {
            let part = String(chapter.content.prefix(remaining))
            parts.append(part)
            remaining -= part.count
        }
        return parts.joined(separator: " ")
    }
}
