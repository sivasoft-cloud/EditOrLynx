import AVFoundation
import Foundation

/// Plays the short interface cues used by the notch.
@MainActor
final class SoundPlayer {
    static let shared = SoundPlayer()

    enum Cue: String, CaseIterable {
        case link
        case complete
        case copy
        case clip
        case drop
        case failed
    }

    private static let enabledKey = "notchSounds"
    private var cache: [Cue: AVAudioPlayer] = [:]

    var isEnabled: Bool {
        get {
            guard let stored = UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool else { return true }
            return stored
        }
        set { UserDefaults.standard.set(newValue, forKey: Self.enabledKey) }
    }

    func preload() {
        guard isEnabled else { return }
        for cue in Cue.allCases where cache[cue] == nil {
            guard let url = Bundle.module.url(forResource: cue.rawValue, withExtension: "caf") else { continue }
            if let player = try? AVAudioPlayer(contentsOf: url) {
                player.volume = 0.75
                player.prepareToPlay()
                cache[cue] = player
            }
        }
    }

    func play(_ cue: Cue) {
        guard isEnabled else { return }
        if let player = cache[cue] {
            player.currentTime = 0
            player.play()
            return
        }
        guard let url = Bundle.module.url(forResource: cue.rawValue, withExtension: "caf"),
              let player = try? AVAudioPlayer(contentsOf: url) else { return }
        player.volume = 0.75
        player.prepareToPlay()
        cache[cue] = player
        player.play()
    }
}
