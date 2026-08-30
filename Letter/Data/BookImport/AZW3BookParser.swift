import Foundation
import UIKit

struct AZW3BookParser: BookDocumentParser {
    let format = BookFormat.azw3
    private let segmenter = BookChapterSegmenter()

    func parse(url: URL, fallbackTitle: String) throws -> ParsedBookDocument {
        let data = try Data(contentsOf: url)
        guard data.count >= 86,
              let recordCount = data.bigEndianUInt16(at: 76),
              recordCount > 1 else {
            throw AudioBookError.malformedDocument
        }
        let offsets = try recordOffsets(in: data, count: Int(recordCount))
        let header = data.subdata(in: offsets[0]..<offsets[1])
        guard let compression = header.bigEndianUInt16(at: 0),
              let textLength = header.bigEndianUInt32(at: 4),
              let textRecordCount = header.bigEndianUInt16(at: 8),
              let encryption = header.bigEndianUInt16(at: 12) else {
            throw AudioBookError.malformedDocument
        }
        guard encryption == 0 else { throw AudioBookError.protectedDocument }
        guard compression == 1 || compression == 2 else {
            throw AudioBookError.unsupportedCompression
        }

        let availableTextRecords = min(Int(textRecordCount), offsets.count - 2)
        guard availableTextRecords > 0 else { throw AudioBookError.emptyBook }
        var contentData = Data()
        for recordIndex in 1...availableTextRecords {
            let record = data.subdata(in: offsets[recordIndex]..<offsets[recordIndex + 1])
            contentData.append(try decode(record: record, compression: compression))
        }
        if contentData.count > Int(textLength) {
            contentData = Data(contentData.prefix(Int(textLength)))
        }

        guard let source = decodedText(contentData, header: header) else {
            throw AudioBookError.malformedDocument
        }
        let text = renderedText(source)
        let chapters = segmenter.chapters(from: text, fallbackTitle: fallbackTitle)
        guard !chapters.isEmpty else { throw AudioBookError.emptyBook }
        return ParsedBookDocument(title: fallbackTitle, chapters: chapters)
    }

    private func recordOffsets(in data: Data, count: Int) throws -> [Int] {
        let recordTableEnd = 78 + count * 8
        var offsets: [Int] = []
        for index in 0..<count {
            guard let offset = data.bigEndianUInt32(at: 78 + index * 8) else {
                throw AudioBookError.malformedDocument
            }
            offsets.append(Int(offset))
        }
        offsets.append(data.count)
        guard offsets == offsets.sorted(),
              offsets.dropLast().allSatisfy({ $0 >= recordTableEnd && $0 < data.count }),
              offsets.last == data.count else {
            throw AudioBookError.malformedDocument
        }
        return offsets
    }

    private func decode(record: Data, compression: UInt16) throws -> Data {
        guard compression == 2 else { return record }
        var output: [UInt8] = []
        let bytes = [UInt8](record)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            switch byte {
            case 0, 9...127:
                output.append(byte)
            case 1...8:
                let length = Int(byte)
                guard index + length <= bytes.count else { throw AudioBookError.malformedDocument }
                output.append(contentsOf: bytes[index..<(index + length)])
                index += length
            case 128...191:
                guard index < bytes.count else { throw AudioBookError.malformedDocument }
                let pair = (Int(byte) << 8) | Int(bytes[index])
                index += 1
                let distance = (pair >> 3) & 0x7FF
                let length = (pair & 0x7) + 3
                guard distance > 0, distance <= output.count else {
                    throw AudioBookError.malformedDocument
                }
                for _ in 0..<length { output.append(output[output.count - distance]) }
            default:
                output.append(32)
                output.append(byte ^ 0x80)
            }
        }
        return Data(output)
    }

    private func decodedText(_ data: Data, header: Data) -> String? {
        let mobiEncoding = header.bigEndianUInt32(at: 28)
        if mobiEncoding == 65001 { return String(data: data, encoding: .utf8) }
        if mobiEncoding == 1252 { return String(data: data, encoding: .windowsCP1252) }
        return data.decodedBookText
    }

    private func renderedText(_ source: String) -> String {
        guard source.localizedCaseInsensitiveContains("<html")
                || source.localizedCaseInsensitiveContains("<body") else {
            return source.replacingOccurrences(of: "\0", with: "")
        }
        let data = Data(source.utf8)
        let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        )
        return (attributed?.string ?? source)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private extension Data {
    func bigEndianUInt16(at offset: Int) -> UInt16? {
        guard offset >= 0, offset + 2 <= count else { return nil }
        return self[offset..<offset + 2].reduce(0) { ($0 << 8) | UInt16($1) }
    }

    func bigEndianUInt32(at offset: Int) -> UInt32? {
        guard offset >= 0, offset + 4 <= count else { return nil }
        return self[offset..<offset + 4].reduce(0) { ($0 << 8) | UInt32($1) }
    }
}
