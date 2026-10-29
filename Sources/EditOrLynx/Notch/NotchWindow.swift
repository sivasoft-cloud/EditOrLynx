import AppKit

public final class NotchPanel: NSPanel {
    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    /// Override that prevents AppKit from forcing the panel below the menu bar
    override public func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        frameRect
    }

    public init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = false
        hidesOnDeactivate = false
        isMovableByWindowBackground = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        animationBehavior = .none
        becomesKeyOnlyIfNeeded = false
        acceptsMouseMovedEvents = true
        sharingType = .readOnly
    }
}
