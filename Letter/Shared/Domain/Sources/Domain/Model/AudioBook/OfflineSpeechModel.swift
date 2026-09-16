import Foundation

public enum OfflineSpeechModel: String, CaseIterable, Sendable, Hashable {
    case vieNeuV3Turbo
    case vieNeuV3Nano
    case kokoro82M

    public var language: BookLanguage {
        switch self {
        case .vieNeuV3Turbo, .vieNeuV3Nano: .vietnamese
        case .kokoro82M: .english
        }
    }

    public var availableVoices: [OfflineSpeechVoice] {
        switch self {
        case .vieNeuV3Turbo:
            OfflineSpeechVoice.vieNeuVoices
        case .vieNeuV3Nano:
            OfflineSpeechVoice.vieNeuNanoVoices
        case .kokoro82M:
            [.kokoroHeart, .kokoroMichael]
        }
    }

    public var defaultVoice: OfflineSpeechVoice? {
        switch self {
        case .vieNeuV3Turbo: .ngocLinh
        case .vieNeuV3Nano: .adam
        case .kokoro82M: .kokoroHeart
        }
    }

    public static var defaultModels: [BookLanguage: Self] {
        Dictionary(uniqueKeysWithValues: BookLanguage.allCases.compactMap { language in
            models(for: language).first.map { (language, $0) }
        })
    }

    public static func resolve(_ model: Self?, for language: BookLanguage) -> Self? {
        if let model, model.language == language { return model }
        return models(for: language).first
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
    public static let adam = Self(rawValue: "Adam")
    public static let kokoroHeart = Self(rawValue: "af_heart")
    public static let kokoroMichael = Self(rawValue: "am_michael")

    public static let vieNeuNanoVoices: [Self] = [
        .adam, Self(rawValue: "Ái Hân"), Self(rawValue: "Mỹ Duyên"),
        Self(rawValue: "Đức Trí"), Self(rawValue: "Hữu Quân"), Self(rawValue: "Xuân Tiên"),
        .maiAnh, .trucLy, Self(rawValue: "Anh Khôi"),
        Self(rawValue: "Minh Quân"), Self(rawValue: "Mạnh Dũng")
    ]

    public static let vieNeuVoices: [Self] = [
        .trucLy, .phamTuyen, .thaiSon, .xuanVinh, .thanhBinh,
        .minhDuc, .ngocLinh, .doanTrang, .maiAnh, .thucDoan
    ]
}
