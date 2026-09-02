import Foundation

struct ImportedBookTextNormalizer: Sendable {
    func normalizeDocument(_ text: String) -> String {
        let canonical = text.precomposedStringWithCanonicalMapping
        let sanitized = sanitizeScalars(in: canonical)
        return joiningWrappedHyphens(in: sanitized)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func normalizePDFPages(_ pages: [String]) -> [String] {
        let normalizedPages = pages.map(normalizeDocument)
        let removesPageNumbers = hasRecurringPageNumberMargins(in: normalizedPages)
        return removingRecurringMargins(
            from: normalizedPages,
            removesPageNumbers: removesPageNumbers
        )
    }

    func normalizeSections(_ sections: [String]) -> [String] {
        removingRecurringMargins(
            from: sections.map(normalizeDocument),
            removesPageNumbers: false
        )
    }

    private func removingRecurringMargins(
        from sections: [String],
        removesPageNumbers: Bool
    ) -> [String] {
        let recurringMargins = recurringMarginKeys(in: sections)
        guard !recurringMargins.isEmpty || removesPageNumbers else {
            return sections
        }
        var retainedRecurringMargins: Set<String> = []
        return sections.map { section in
            removingRepeatedMargins(
                from: section,
                recurringKeys: recurringMargins,
                removesPageNumbers: removesPageNumbers,
                retainedKeys: &retainedRecurringMargins
            )
        }
    }

    private func sanitizeScalars(in text: String) -> String {
        var result = String.UnicodeScalarView()
        result.reserveCapacity(text.unicodeScalars.count)
        var pendingSpace = false
        var previousWasCarriageReturn = false
        var consecutiveNewlines = 0

        for scalar in text.unicodeScalars {
            if scalar.value == 0x0D {
                appendNewline(to: &result, consecutiveNewlines: &consecutiveNewlines)
                pendingSpace = false
                previousWasCarriageReturn = true
                continue
            }
            if scalar.value == 0x0A || scalar.value == 0x2028 || scalar.value == 0x2029 {
                if !previousWasCarriageReturn {
                    appendNewline(to: &result, consecutiveNewlines: &consecutiveNewlines)
                    if scalar.value == 0x2029 {
                        appendNewline(to: &result, consecutiveNewlines: &consecutiveNewlines)
                    }
                }
                pendingSpace = false
                previousWasCarriageReturn = false
                continue
            }
            previousWasCarriageReturn = false

            if isInvisibleFormatting(scalar) { continue }
            if isDiscardedScalar(scalar) {
                pendingSpace = !result.isEmpty && consecutiveNewlines == 0
                continue
            }
            if isHorizontalWhitespace(scalar) {
                pendingSpace = !result.isEmpty && consecutiveNewlines == 0
                continue
            }

            if pendingSpace,
               shouldInsertSpace(after: result.last, before: scalar) {
                result.append(" ")
            }
            pendingSpace = false
            consecutiveNewlines = 0
            result.append(scalar)
        }
        return String(result)
    }

    private func appendNewline(
        to result: inout String.UnicodeScalarView,
        consecutiveNewlines: inout Int
    ) {
        guard !result.isEmpty, consecutiveNewlines < 2 else { return }
        result.append("\n")
        consecutiveNewlines += 1
    }

    private func shouldInsertSpace(
        after previous: UnicodeScalar?,
        before next: UnicodeScalar
    ) -> Bool {
        let noSpaceBefore = CharacterSet(charactersIn: ",.;:!?%)]}")
        let noSpaceAfter = CharacterSet(charactersIn: "([{“‘")
        return !noSpaceBefore.contains(next)
            && previous.map { !noSpaceAfter.contains($0) } != false
    }

    private func isHorizontalWhitespace(_ scalar: UnicodeScalar) -> Bool {
        scalar.value == 0x09
            || scalar.value == 0x20
            || scalar.value == 0x00A0
            || scalar.value == 0x202F
            || scalar.value == 0x3000
    }

    private func isInvisibleFormatting(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x00AD, 0x200B, 0x200C, 0x200D, 0x2060, 0xFEFF:
            true
        default:
            false
        }
    }

    private func isDiscardedScalar(_ scalar: UnicodeScalar) -> Bool {
        if scalar.value == 0xFFFC || scalar.value == 0xFFFD { return true }
        return CharacterSet.controlCharacters.contains(scalar)
            || CharacterSet.illegalCharacters.contains(scalar)
    }

    private func joiningWrappedHyphens(in text: String) -> String {
        text.replacingOccurrences(
            of: #"(?<=\p{L})-\n(?=\p{L})"#,
            with: "-",
            options: .regularExpression
        )
    }

    private func recurringMarginKeys(in pages: [String]) -> Set<String> {
        guard pages.count >= 3 else { return [] }
        var pageCounts: [String: Int] = [:]
        for page in pages {
            let keys = Set(marginLines(in: page).compactMap(marginKey))
            for key in keys { pageCounts[key, default: 0] += 1 }
        }
        let threshold = max(3, Int(ceil(Double(pages.count) * 0.5)))
        return Set(pageCounts.compactMap { key, count in
            count >= threshold ? key : nil
        })
    }

    private func removingRepeatedMargins(
        from page: String,
        recurringKeys: Set<String>,
        removesPageNumbers: Bool,
        retainedKeys: inout Set<String>
    ) -> String {
        let lines = page.components(separatedBy: "\n")
        let marginIndexes = Set(nonemptyMarginIndexes(in: lines))
        let retained = lines.enumerated().compactMap { index, line -> String? in
            guard marginIndexes.contains(index) else { return line }
            if removesPageNumbers, isPageNumber(line) { return nil }
            guard let key = marginKey(line), recurringKeys.contains(key) else {
                return line
            }
            return retainedKeys.insert(key).inserted ? line : nil
        }
        return retained.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func marginLines(in page: String) -> [String] {
        let lines = page.components(separatedBy: "\n")
        return nonemptyMarginIndexes(in: lines).map { lines[$0] }
    }

    private func nonemptyMarginIndexes(in lines: [String]) -> [Int] {
        let nonempty = lines.indices.filter {
            !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty
        }
        return Array((nonempty.prefix(2) + nonempty.suffix(2)).uniqued())
    }

    private func marginKey(_ line: String) -> String? {
        let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value.count <= 120, !isPageNumber(value) else {
            return nil
        }
        return value.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private func hasRecurringPageNumberMargins(in pages: [String]) -> Bool {
        guard pages.count >= 3 else { return false }
        let pagesWithNumber = pages.reduce(0) { count, page in
            count + (marginLines(in: page).contains(where: isPageNumber) ? 1 : 0)
        }
        return pagesWithNumber >= max(3, Int(ceil(Double(pages.count) * 0.5)))
    }

    private func isPageNumber(_ line: String) -> Bool {
        var value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        for prefix in ["page", "trang"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
            value = value.trimmingCharacters(in: .whitespaces)
            return isShortDecimalOrRoman(value)
        }
        return !value.isEmpty
            && value.count <= 6
            && value.allSatisfy(\.isNumber)
    }

    private func isShortDecimalOrRoman(_ value: String) -> Bool {
        let stripped = value.trimmingCharacters(
            in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-–—.()"))
        )
        guard !stripped.isEmpty, stripped.count <= 8 else { return false }
        return stripped.allSatisfy { $0.isNumber || "ivxlcdm".contains($0) }
    }
}

private extension Sequence where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
