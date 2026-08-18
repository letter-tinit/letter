//
//  SoundPlayer.swift
//  Habit
//
//  Created by TiniT on 20/5/26.
//

import AVFoundation

enum SoundPlayer {
    private static var player: AVAudioPlayer?
    
    static func play(_ name: String, extension fileExtension: String = "mp3") {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else {
            return
        }
        
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
        } catch {
            logDebug("Failed to play sound: \(error)")
        }
    }
    
    static func done() {
        play("apple-pay-success-sound-effect")
    }
    
    static func completed() {
        play("apple-pay-success-sound-effect")
    }
}
