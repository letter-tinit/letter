import AVFoundation

public func appleSpeechRate(multiplier: Double) -> Float {
    let proposed: Float
    if multiplier <= 1 {
        proposed = AVSpeechUtteranceDefaultSpeechRate * Float(multiplier)
    } else {
        let normalized = Float((multiplier - 1) / 2)
        proposed = AVSpeechUtteranceDefaultSpeechRate
            + (AVSpeechUtteranceMaximumSpeechRate - AVSpeechUtteranceDefaultSpeechRate) * normalized
    }
    return min(max(proposed, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
}
