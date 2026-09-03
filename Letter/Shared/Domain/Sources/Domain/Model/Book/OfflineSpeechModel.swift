import Foundation

public enum OfflineSpeechModel: String, CaseIterable, Sendable, Hashable {
    case matchaLJSpeech
    case piperVais1000
    case vieNeuV3Turbo

    public var language: BookLanguage {
        switch self {
        case .matchaLJSpeech: .english
        case .piperVais1000, .vieNeuV3Turbo: .vietnamese
        }
    }

    public var availableVoices: [OfflineSpeechVoice] {
        switch self {
        case .matchaLJSpeech, .piperVais1000:
            []
        case .vieNeuV3Turbo:
            OfflineSpeechVoice.vieNeuVoices
        }
    }

    public var defaultVoice: OfflineSpeechVoice? {
        availableVoices.first(where: { $0 == .ngocLinh })
    }

    public static func models(for language: BookLanguage) -> [Self] {
        allCases.filter { $0.language == language }
    }
}

public struct OfflineSpeechVoice: RawRepresentable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) { self.rawValue = rawValue }

    public static let trucLy = Self(rawValue: "Trúc Ly")
    public static let phamTuyen = Self(rawValue: "Phạm Tuyên")
    public static let thaiSon = Self(rawValue: "Thái Sơn")
    public static let xuanVinh = Self(rawValue: "Xuân Vĩnh")
    public static let thanhBinh = Self(rawValue: "Thanh Bình")
    public static let minhDuc = Self(rawValue: "Minh Đức")
    public static let ngocLinh = Self(rawValue: "Ngọc Linh")
    public static let doanTrang = Self(rawValue: "Đoan Trang")
    public static let maiAnh = Self(rawValue: "Mai Anh")
    public static let thucDoan = Self(rawValue: "Thục Đoan")

    public static let vieNeuVoices: [Self] = [
        .trucLy, .phamTuyen, .thaiSon, .xuanVinh, .thanhBinh,
        .minhDuc, .ngocLinh, .doanTrang, .maiAnh, .thucDoan
    ]
}
