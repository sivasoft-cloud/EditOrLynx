import AppKit
import Combine
import Foundation
import SwiftUI

@MainActor
public final class NotchWindowController: NSWindowController {
    public static let shared = NotchWindowController()

    private var trackingArea: NSTrackingArea?
    private var hoverTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private init() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 214, height: 34),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = false

        super.init(window: panel)

        setupStateObservation()
        setupScreenChangeObservation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public func setup() {
        let rootView = NotchRootView { [weak self] hovering in
            self?.handleHover(hovering)
        }
        .environmentObject(DownloadEngine.shared)
        .environmentObject(NotchState.shared)

        let hosting = NSHostingView(rootView: rootView)
        hosting.autoresizingMask = [.width, .height]
        window?.contentView = hosting

        reposition(animated: false)
        window?.orderFrontRegardless()
        setupTrackingArea()
    }

    private func setupStateObservation() {
        NotchState.shared.$mode
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)

        NotchState.shared.$isLockedExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reposition(animated: true)
            }
            .store(in: &cancellables)
    }

    private func setupScreenChangeObservation() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.reposition(animated: false)
            }
        }
    }

    public func show() {
        reposition(animated: false)
        window?.orderFrontRegardless()
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func toggleExpanded() {
        show()
        NotchState.shared.toggleExpand()
    }

    private func handleHover(_ hovering: Bool) {
        hoverTimer?.invalidate()
        if hovering {
            NotchState.shared.isHovered = true
            reposition(animated: true)
        } else {
            hoverTimer = Timer.scheduledTimer(withTimeInterval: 0.45, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    if !NotchState.shared.isLockedExpanded {
                        NotchState.shared.isHovered = false
                        self.reposition(animated: true)
                    }
                }
            }
        }
    }

    public func reposition(animated: Bool = true) {
        guard let window else { return }
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.screens.first ?? NSScreen.main else { return }

        let state = NotchState.shared
        let width: CGFloat
        let height: CGFloat
        if state.isExpanded {
            width = (state.mode == .offer ? 480 : state.expandedWidth)
            height = (state.mode == .offer ? 180 : state.expandedHeight) + 48
        } else {
            width = state.compactWidth
            height = state.compactHeight
        }

        let screenFrame = screen.frame
        let midX = screenFrame.midX
        let topY = screenFrame.maxY

        // Pinned directly flush to top edge (exact stock Lynx placement)
        let targetY = topY - height

        let targetFrame = NSRect(
            x: midX - (width / 2),
            y: targetY,
            width: width,
            height: height
        )

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.30
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                window.animator().setFrame(targetFrame, display: true)
            }
        } else {
            window.setFrame(targetFrame, display: true)
        }

        setupTrackingArea()
    }

    private func setupTrackingArea() {
        guard let view = window?.contentView else { return }
        if let existing = trackingArea {
            view.removeTrackingArea(existing)
        }

        let options: NSTrackingArea.Options = [
            .mouseEnteredAndExited,
            .activeAlways,
            .inVisibleRect
        ]
        let area = NSTrackingArea(rect: view.bounds, options: options, owner: self, userInfo: nil)
        view.addTrackingArea(area)
        self.trackingArea = area
    }
}
