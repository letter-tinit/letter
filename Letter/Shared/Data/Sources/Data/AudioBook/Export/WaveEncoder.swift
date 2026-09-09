import Foundation

enum WaveEncoder {
    static func encode(samples: [Float], sampleRate: Int) -> Data {
        let pcm = samples.map { sample -> Int16 in
            let clamped = min(max(sample, -1), 1)
            return Int16(clamped * Float(Int16.max))
        }
        let dataSize = UInt32(pcm.count * MemoryLayout<Int16>.size)
        var data = Data()
        data.appendASCII("RIFF")
        data.appendLittleEndian(UInt32(36) + dataSize)
        data.appendASCII("WAVEfmt ")
        data.appendLittleEndian(UInt32(16))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt16(1))
        data.appendLittleEndian(UInt32(sampleRate))
        data.appendLittleEndian(UInt32(sampleRate * 2))
        data.appendLittleEndian(UInt16(2))
        data.appendLittleEndian(UInt16(16))
        data.appendASCII("data")
        data.appendLittleEndian(dataSize)
        for sample in pcm { data.appendLittleEndian(UInt16(bitPattern: sample)) }
        return data
    }
}

private extension Data {
    mutating func appendASCII(_ string: String) {
        append(contentsOf: string.utf8)
    }

    mutating func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var value = value.littleEndian
        Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) }
    }
}
