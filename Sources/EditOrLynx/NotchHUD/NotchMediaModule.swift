import SwiftUI

public struct NotchMediaModule: View {
    @State private var isPlaying: Bool = false
    @State private var trackTitle: String = "No Media Playing"
    @State private var artist: String = "Launch Music or Spotify"

    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 48, height: 48)
                Image(systemName: "music.note")
                    .font(.system(size: 20))
                    .foregroundColor(Color.accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(trackTitle)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(artist)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 12) {
                Button {
                    skipTrack(forward: false)
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                Button {
                    togglePlayPause()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)

                Button {
                    skipTrack(forward: true)
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .onAppear {
            refreshNowPlaying()
        }
    }

    private func togglePlayPause() {
        isPlaying.toggle()
        let script = "tell application \"Music\" to playpause"
        _ = try? NSUserAppleScriptTask(url: URL(fileURLWithPath: "/tmp/dummy"))
        runAppleScript(script)
    }

    private func skipTrack(forward: Bool) {
        let cmd = forward ? "next track" : "previous track"
        runAppleScript("tell application \"Music\" to \(cmd)")
    }

    private func refreshNowPlaying() {
        // Query Music status via AppleScript
        let script = "tell application \"System Events\"\n if exists (process \"Music\") then\n tell application \"Music\" to return {player state as string, name of current track, artist of current track}\n end if\n end tell"
        if let res = runAppleScript(script) {
            let parts = res.components(separatedBy: ", ")
            if parts.count >= 3 {
                isPlaying = parts[0].lowercased().contains("playing")
                trackTitle = parts[1]
                artist = parts[2]
            }
        }
    }

    @discardableResult
    private func runAppleScript(_ source: String) -> String? {
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: source) {
            let output = scriptObject.executeAndReturnError(&error)
            return output.stringValue
        }
        return nil
    }
}
