public protocol GoogleCloudSpeechUsageRepository: AnyObject, Sendable {
    func currentUsage() -> GoogleCloudSpeechUsage
    func reserve(characterCount: Int) -> Bool
}
