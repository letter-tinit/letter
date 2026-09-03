import Domain

extension GoogleCloudVoicePreference {
    func displayName(for language: BookLanguage) -> String {
        switch (language, self) {
        case (.vietnamese, .femaleOne): "vi-VN-Wavenet-A"
        case (.vietnamese, .femaleTwo): "vi-VN-Wavenet-C"
        case (.vietnamese, .maleOne): "vi-VN-Wavenet-B"
        case (.vietnamese, .maleTwo): "vi-VN-Wavenet-D"
        case (.english, .femaleOne): "en-US-Wavenet-F"
        case (.english, .femaleTwo): "en-US-Wavenet-C"
        case (.english, .maleOne): "en-US-Wavenet-D"
        case (.english, .maleTwo): "en-US-Wavenet-A"
        }
    }
}
