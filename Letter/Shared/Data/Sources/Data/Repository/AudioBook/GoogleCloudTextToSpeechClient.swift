import CryptoKit
import Foundation
import Domain

public struct GoogleCloudSpeechRequest: Sendable {
    public let text: String
    public let languageCode: String
    public let rate: Double

    public init(text: String, languageCode: String, rate: Double) {
        self.text = text
        self.languageCode = languageCode
        self.rate = rate
    }
}

public protocol GoogleCloudSpeechSynthesizing: Sendable {
    func synthesize(_ request: GoogleCloudSpeechRequest) async throws -> Data
}

public enum GoogleCloudSpeechError: Error {
    case missingCredential
    case invalidRequest
    case invalidResponse
    case requestFailed(statusCode: Int)
}

public final class GoogleCloudTextToSpeechClient: GoogleCloudSpeechSynthesizing, @unchecked Sendable {
    private let endpoint = URL(string: "https://texttospeech.googleapis.com/v1/text:synthesize")!
    private let settings: any SpeechProviderSettingsRepository
    private let usage: any GoogleCloudSpeechUsageRepository
    private let session: URLSession
    private let cache: GoogleCloudSpeechAudioCache
    private let bundleIdentifier: String

    public init(
        settings: any SpeechProviderSettingsRepository,
        usage: any GoogleCloudSpeechUsageRepository,
        session: URLSession = .shared,
        fileManager: FileManager = .default,
        bundleIdentifier: String = Bundle.main.bundleIdentifier ?? "com.lettertinit.Letter"
    ) {
        self.settings = settings
        self.usage = usage
        self.session = session
        cache = GoogleCloudSpeechAudioCache(fileManager: fileManager)
        self.bundleIdentifier = bundleIdentifier
    }

    public func synthesize(_ request: GoogleCloudSpeechRequest) async throws -> Data {
        guard !request.text.isEmpty, request.text.utf8.count <= 5_000 else {
            throw GoogleCloudSpeechError.invalidRequest
        }
        let voice = GoogleCloudVoiceCatalog.voice(
            languageCode: request.languageCode,
            preference: settings.loadGoogleCloudVoice()
        )
        let rate = min(max(request.rate, 0.25), 2)
        let cacheKey = cache.key(text: request.text, voice: voice, rate: rate)
        if let cached = cache.load(key: cacheKey) { return cached }

        guard let apiKey = normalizedAPIKey else {
            throw GoogleCloudSpeechError.missingCredential
        }
        let data = try await requestAudio(
            text: request.text,
            languageCode: request.languageCode,
            voice: voice,
            rate: rate,
            apiKey: apiKey
        )
        try cache.save(data, key: cacheKey)
        return data
    }

    private var normalizedAPIKey: String? {
        guard let value = settings.loadGoogleCloudAPIKey()?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func requestAudio(
        text: String,
        languageCode: String,
        voice: String,
        rate: Double,
        apiKey: String
    ) async throws -> Data {
        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")
        urlRequest.setValue(bundleIdentifier, forHTTPHeaderField: "x-ios-bundle-identifier")
        urlRequest.httpBody = try JSONEncoder().encode(
            SynthesisRequest(
                input: .init(text: text),
                voice: .init(languageCode: languageCode, name: voice),
                audioConfig: .init(audioEncoding: "MP3", speakingRate: rate)
            )
        )
        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleCloudSpeechError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw GoogleCloudSpeechError.requestFailed(statusCode: httpResponse.statusCode)
        }
        let payload = try JSONDecoder().decode(SynthesisResponse.self, from: data)
        guard let audio = Data(base64Encoded: payload.audioContent) else {
            throw GoogleCloudSpeechError.invalidResponse
        }
        usage.recordSuccessfulSynthesis(characterCount: text.count)
        return audio
    }
}

private enum GoogleCloudVoiceCatalog {
    static func voice(
        languageCode: String,
        preference: GoogleCloudVoicePreference
    ) -> String {
        if languageCode.lowercased().hasPrefix("vi") {
            switch preference {
            case .femaleOne: "vi-VN-Wavenet-A"
            case .femaleTwo: "vi-VN-Wavenet-C"
            case .maleOne: "vi-VN-Wavenet-B"
            case .maleTwo: "vi-VN-Wavenet-D"
            }
        } else {
            switch preference {
            case .femaleOne: "en-US-Wavenet-F"
            case .femaleTwo: "en-US-Wavenet-C"
            case .maleOne: "en-US-Wavenet-D"
            case .maleTwo: "en-US-Wavenet-A"
            }
        }
    }
}

private struct SynthesisRequest: Encodable {
    struct Input: Encodable { let text: String }
    struct Voice: Encodable { let languageCode: String; let name: String }
    struct AudioConfig: Encodable { let audioEncoding: String; let speakingRate: Double }
    let input: Input
    let voice: Voice
    let audioConfig: AudioConfig
}

private struct SynthesisResponse: Decodable {
    let audioContent: String
}

private final class GoogleCloudSpeechAudioCache: @unchecked Sendable {
    private let directory: URL
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
        let base = (try? fileManager.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fileManager.temporaryDirectory
        directory = base.appendingPathComponent("GoogleCloudSpeech", isDirectory: true)
    }

    func key(text: String, voice: String, rate: Double) -> String {
        let source = "\(voice)|\(String(format: "%.2f", rate))|\(text)"
        return SHA256.hash(data: Data(source.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func load(key: String) -> Data? {
        try? Data(contentsOf: fileURL(key: key), options: .mappedIfSafe)
    }

    func save(_ data: Data, key: String) throws {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: fileURL(key: key), options: .atomic)
    }

    private func fileURL(key: String) -> URL {
        directory.appendingPathComponent(key).appendingPathExtension("mp3")
    }
}
