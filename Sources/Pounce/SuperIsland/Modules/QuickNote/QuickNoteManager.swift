import AppKit
import SwiftUI

@MainActor
final class QuickNoteManager: ObservableObject {
    static let shared = QuickNoteManager()

    @AppStorage("quicknote.content") var content: String = ""
    @AppStorage("quicknote.pinned") var isPinned: Bool = false
    @Published var lastSavedText: String = ""

    private init() {
        lastSavedText = content
    }

    var characterCount: Int {
        content.count
    }

    var wordCount: Int {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }
        return trimmed.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }

    func copyToClipboard() {
        guard !content.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    func clearNote() {
        content = ""
        lastSavedText = ""
    }

    func saveToFile() {
        guard !content.isEmpty else { return }
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.plainText]
        savePanel.nameFieldStringValue = "Note-\(formattedCurrentDate()).txt"
        savePanel.title = "Save Quick Note"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? content.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    private func formattedCurrentDate() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        return formatter.string(from: Date())
    }
}
