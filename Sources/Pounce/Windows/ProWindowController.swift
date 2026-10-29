import AppKit
import SwiftUI

@MainActor
final class ProWindowController: NSWindowController {
    private weak var model: AppModel?

    init(model: AppModel) {
        self.model = model
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Edit.or.lynx Pro"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.minSize = NSSize(width: 520, height: 560)
        window.isMovableByWindowBackground = true
        window.center()
        let hosting = NSHostingView(rootView: ProView(model: model))
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        // Reroute to in-app view so no detached window opens
        model?.openPro?()
    }
}
