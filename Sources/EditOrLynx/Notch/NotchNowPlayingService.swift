import AppKit
import Foundation

@MainActor
public final class NotchNowPlayingService: NSObject {
    public static let shared = NotchNowPlayingService()

    private var pollTimer: Timer?

    private override init() {
        super.init()
        setupListeners()
        pollAppleMusic()
    }

    private func setupListeners() {
        // Spotify notification listener
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(spotifyPlaybackChanged(_:)),
            name: NSNotification.Name("com.spotify.client.PlaybackStateChanged"),
            object: nil
        )

        // Apple Music timer poller (every 4 seconds when active)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollAppleMusic()
            }
        }
    }

    @objc private func spotifyPlaybackChanged(_ notification: Notification) {
        guard let info = notification.userInfo else { return }
        let playerState = info["Player State"] as? String ?? ""
        let isPlaying = (playerState.lowercased() == "playing")
        let trackName = info["Name"] as? String ?? "Unknown Track"
        let artist = info["Artist"] as? String ?? "Unknown Artist"

        NotchState.shared.isPlayingMusic = isPlaying
        NotchState.shared.nowPlayingTitle = trackName
        NotchState.shared.nowPlayingArtist = artist
    }

    public func pollAppleMusic() {
        // If Spotify is already actively playing, let Spotify take priority
        let runningSpotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        if !runningSpotify.isEmpty && NotchState.shared.isPlayingMusic {
            return
        }

        let runningMusic = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        guard !runningMusic.isEmpty else { return }

        let scriptText = """
        tell application "Music"
            if player state is playing then
                set trackName to name of current track
                set artistName to artist of current track
                return "PLAYING|" & trackName & "|" & artistName
            else if player state is paused then
                set trackName to name of current track
                set artistName to artist of current track
                return "PAUSED|" & trackName & "|" & artistName
            else
                return "STOPPED"
            end if
        end tell
        """

        DispatchQueue.global(qos: .userInitiated).async {
            var error: NSDictionary?
            let script = NSAppleScript(source: scriptText)
            let result = script?.executeAndReturnError(&error)
            let stringVal = result?.stringValue ?? ""

            DispatchQueue.main.async {
                let parts = stringVal.split(separator: "|")
                if parts.count >= 3 {
                    let state = String(parts[0])
                    let track = String(parts[1])
                    let artist = String(parts[2])
                    NotchState.shared.isPlayingMusic = (state == "PLAYING")
                    NotchState.shared.nowPlayingTitle = track
                    NotchState.shared.nowPlayingArtist = artist
                } else if stringVal == "STOPPED" && runningSpotify.isEmpty {
                    NotchState.shared.isPlayingMusic = false
                }
            }
        }
    }

    public func togglePlayPause() {
        let runningSpotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        if !runningSpotify.isEmpty {
            runAppleScript("""
            tell application "Spotify" to playpause
            """)
            NotchState.shared.isPlayingMusic.toggle()
            return
        }

        let runningMusic = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music")
        if !runningMusic.isEmpty {
            runAppleScript("""
            tell application "Music" to playpause
            """)
            NotchState.shared.isPlayingMusic.toggle()
        }
    }

    public func nextTrack() {
        let runningSpotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        if !runningSpotify.isEmpty {
            runAppleScript("""
            tell application "Spotify" to next track
            """)
            return
        }
        runAppleScript("""
        tell application "Music" to next track
        """)
    }

    public func previousTrack() {
        let runningSpotify = NSRunningApplication.runningApplications(withBundleIdentifier: "com.spotify.client")
        if !runningSpotify.isEmpty {
            runAppleScript("""
            tell application "Spotify" to previous track
            """)
            return
        }
        runAppleScript("""
        tell application "Music" to previous track
        """)
    }

    private func runAppleScript(_ source: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let script = NSAppleScript(source: source)
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
        }
    }
}
