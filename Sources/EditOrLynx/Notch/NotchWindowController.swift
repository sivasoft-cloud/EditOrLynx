import AppKit
import SwiftUI
import Combine

@MainActor
public final class NotchWindowController: ObservableObject {
    public static let shared = NotchWindowController()

    @Published public var isExpanded: Bool = false
    @Published public var currentSize: CGSize = CGSize(width: 210, height: 32)
    @Published public var selectedTab: NotchHUDTab = .downloads

    private var panel: NotchPanel?
    private var outsideClickMonitor: Any?
    private var mouseMoveMonitor: Any?

    private init() {}

    public func setup() {
        guard let screen = NSScreen.main else { return }
        let geom = NotchGeometry(screen: screen)
        let compact = geom.compactIslandSize(horizontalPadding: 16)
        self.currentSize = compact

        let frame = geom.windowFrame(for: compact)
        let panel = NotchPanel(contentRect: frame)

        let surface = NotchSurfaceView()
            .environmentObject(self)
            .environmentObject(DownloadEngine.shared)

        let hostingView = NSHostingView(rootView: surface)
        panel.contentView = hostingView
        panel.setFrame(frame, display: true)
        panel.orderFrontRegardless()
        self.panel = panel

        setupMonitors()
    }

    public func toggleExpanded() {
        if isExpanded {
            collapse()
        } else {
            expand()
        }
    }

    public func expand() {
        isExpanded = true
        updateFrame(size: CGSize(width: 460, height: 160))
    }

    public func collapse() {
        isExpanded = false
        guard let screen = NSScreen.main else { return }
        let geom = NotchGeometry(screen: screen)
        let compact = geom.compactIslandSize(horizontalPadding: 16)
        updateFrame(size: compact)
    }

    private func updateFrame(size: CGSize) {
        guard let panel = panel, let screen = NSScreen.main else { return }
        self.currentSize = size
        let geom = NotchGeometry(screen: screen)
        let frame = geom.windowFrame(for: size)

        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.28
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            panel.animator().setFrame(frame, display: true)
        }
    }

    private func setupMonitors() {
        outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self = self, self.isExpanded else { return }
            let loc = NSEvent.mouseLocation
            if let frame = self.panel?.frame, !frame.contains(loc) {
                self.collapse()
            }
        }
    }

    deinit {
        if let m = outsideClickMonitor { NSEvent.removeMonitor(m) }
    }
}
