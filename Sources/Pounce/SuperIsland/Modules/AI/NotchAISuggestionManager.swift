import SwiftUI
import AppKit

public struct AISuggestionItem: Identifiable, Hashable {
    public let id = UUID()
    public let label: String
    public let icon: String
    public let command: String
}

@MainActor
public final class NotchAISuggestionManager: ObservableObject {
    public static let shared = NotchAISuggestionManager()

    @Published public var suggestions: [AISuggestionItem] = []
    @Published public var lastActionResult: String? = nil
    @Published public var isExecuting: Bool = false

    private init() {
        refreshSuggestions()
    }

    public func refreshSuggestions() {
        var items: [AISuggestionItem] = []

        // Context 1: Clipboard has link
        if let model = AppModel.shared, let link = model.detectedLink {
            items.append(AISuggestionItem(label: "Download \(link.title.prefix(16))…", icon: "bolt.fill", command: "download link"))
        }

        // Context 2: Music playing
        if NowPlayingManager.shared.isPlaying {
            items.append(AISuggestionItem(label: "Lossless FLAC", icon: "waveform", command: "flac rip"))
            items.append(AISuggestionItem(label: "Next Track", icon: "forward.fill", command: "next"))
        }

        // Context 3: Active downloads
        if let model = AppModel.shared, model.engine.activeCount > 0 {
            items.append(AISuggestionItem(label: "Pause Downloads", icon: "pause.fill", command: "pause all"))
        }

        // Context 4: Quick Jarvis Mac Control
        items.append(AISuggestionItem(label: "Boost RAM", icon: "bolt.badge.automatic.fill", command: "boost"))
        items.append(AISuggestionItem(label: "Dark Mode", icon: "moon.fill", command: "dark mode"))
        items.append(AISuggestionItem(label: "Screenshot", icon: "camera.fill", command: "screenshot"))
        items.append(AISuggestionItem(label: "Vol 50%", icon: "speaker.wave.2.fill", command: "volume 50"))
        items.append(AISuggestionItem(label: "Torrent File", icon: "arrow.down.doc.fill", command: "open torrent"))
        items.append(AISuggestionItem(label: "Lock Mac", icon: "lock.fill", command: "lock"))
        items.append(AISuggestionItem(label: "Empty Trash", icon: "trash.fill", command: "empty trash"))

        self.suggestions = Array(items.prefix(7))
    }

    public func executeSuggestion(_ item: AISuggestionItem) {
        executeInput(item.command)
    }

    public func executeInput(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isExecuting = true
        lastActionResult = nil

        Task {
            let res: (success: Bool, message: String)
            if text.lowercased() == "open torrent" {
                AppModel.shared?.openTorrentPicker()
                res = (true, "Opened Torrent File Picker 🧲")
            } else if text.lowercased() == "flac rip" {
                AppModel.shared?.downloadCurrentlyPlayingLossless(title: NowPlayingManager.shared.title, artist: NowPlayingManager.shared.artist, album: NowPlayingManager.shared.album)
                res = (true, "Ripping bit-perfect Studio FLAC 🎚️")
            } else if text.lowercased() == "download link" {
                if let model = AppModel.shared, let link = model.detectedLink {
                    model.quickDownload(link)
                    model.dismissDetectedLink()
                    res = (true, "Started Download 🚀")
                } else {
                    res = (false, "No copied link detected.")
                }
            } else {
                res = await MacSystemController.shared.executeCommand(text)
            }

            self.isExecuting = false
            self.lastActionResult = res.message
            self.refreshSuggestions()

            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if self.lastActionResult == res.message {
                    self.lastActionResult = nil
                }
            }
        }
    }
}
