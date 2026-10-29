import AppKit
import SwiftUI

@MainActor
final class DownloadOnboardingWindowController: NSWindowController {
    private let model: AppModel

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Edit.or.lynx"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.minSize = NSSize(width: 660, height: 480)
        window.isMovableByWindowBackground = true
        window.center()

        super.init(window: window)

        let hosting = NSHostingView(
            rootView: DownloadOnboardingView(model: model) { [weak self] in
                UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                self?.window?.close()
                model.showToast("Edit.or.lynx is ready in your notch!", symbol: "sparkles")
            }
        )
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
