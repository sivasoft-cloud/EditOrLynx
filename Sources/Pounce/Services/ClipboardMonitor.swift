import AppKit
import Foundation

@MainActor
final class ClipboardMonitor {
    var onCapture: (@MainActor (String, String?, String?) -> Void)?
    var isEnabled: Bool = true

    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoredChangeCount: Int = -1

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.6, target: self, selector: #selector(poll), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        lastChangeCount = pasteboard.changeCount
        ignoredChangeCount = pasteboard.changeCount
    }

    @objc private func poll() {
        let pasteboard = NSPasteboard.general
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount
        guard isEnabled, changeCount != ignoredChangeCount else { return }
        guard let text = pasteboard.string(forType: .string) else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 20_000 else { return }

        let app = NSWorkspace.shared.frontmostApplication
        var sourceName = app?.localizedName
        var bundleID = app?.bundleIdentifier
        if bundleID == Bundle.main.bundleIdentifier {
            sourceName = "Edit.or.lynx"
            bundleID = Bundle.main.bundleIdentifier
        }
        onCapture?(text, sourceName, bundleID)
    }
}
