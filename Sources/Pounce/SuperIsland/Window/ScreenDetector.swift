import AppKit

enum ScreenDetector {
    struct CompactIslandMetrics {
        let size: CGSize
        let bottomCornerRadius: CGFloat
    }

    /// Check if the given screen has a physical hardware notch (MacBook Pro 14"/16" etc.)
    static func hasNotch(screen: NSScreen) -> Bool {
        let geometry = NotchGeometry(screen: screen)
        return geometry.hasPhysicalNotch
    }

    /// Get the notch rectangle area for positioning
    static func notchRect(screen: NSScreen) -> NSRect? {
        let geometry = NotchGeometry(screen: screen)
        return geometry.hardwareNotchRect
    }

    /// Get detailed NotchGeometry object for screen
    static func geometry(for screen: NSScreen) -> NotchGeometry {
        NotchGeometry(screen: screen)
    }

    static func compactIslandMetrics(screen: NSScreen) -> CompactIslandMetrics? {
        let geom = NotchGeometry(screen: screen)
        guard geom.hasPhysicalNotch else { return nil }

        let width = max(
            Constants.compactNotchMinimumWidth,
            geom.hardwareNotchWidth - (Constants.compactNotchHorizontalInset * 2)
        )
        let height = max(
            Constants.compactNotchMinimumHeight,
            geom.hardwareNotchHeight - Constants.compactNotchHeightInset
        )
        let bottomCornerRadius = min(Constants.compactNotchBottomCornerRadius, height / 2.0)

        return CompactIslandMetrics(
            size: CGSize(width: width, height: height),
            bottomCornerRadius: bottomCornerRadius
        )
    }

    /// Get the screen that the mouse cursor is currently on
    static var activeScreen: NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { screen in
            screen.frame.contains(mouseLocation)
        }
    }

    /// Get the primary screen
    static var primaryScreen: NSScreen? {
        NSScreen.main
    }

    /// Stable, per-display identifier string (`CGDirectDisplayID` as text).
    /// Persisted in settings so the user's chosen display survives relaunches.
    static func displayIDString(for screen: NSScreen) -> String? {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        guard let number = screen.deviceDescription[key] as? NSNumber else {
            return nil
        }
        return String(number.uint32Value)
    }

    /// Find a screen by the identifier produced by `displayIDString`.
    static func screen(withIDString id: String) -> NSScreen? {
        guard !id.isEmpty else { return nil }
        return NSScreen.screens.first { displayIDString(for: $0) == id }
    }

    /// Sentinel id for the "show on every connected display" mode.
    static let allDisplaysIdentifier = "all"

    /// Human-readable list of the connected screens for the display picker.
    /// First entry is always "Automatic" (empty id == follow default rules).
    struct ScreenOption: Identifiable, Hashable {
        let id: String           // "" for Automatic, "all" for every display, otherwise CGDirectDisplayID string
        let name: String
    }

    static func availableScreenOptions() -> [ScreenOption] {
        var options: [ScreenOption] = [ScreenOption(id: "", name: "Automatic")]
        if NSScreen.screens.count > 1 {
            options.append(ScreenOption(id: allDisplaysIdentifier, name: "All Displays"))
        }
        for screen in NSScreen.screens {
            guard let id = displayIDString(for: screen) else { continue }
            let name: String
            if #available(macOS 14.0, *), !screen.localizedName.isEmpty {
                name = screen.localizedName
            } else {
                let size = screen.frame.size
                name = "Display (\(Int(size.width))×\(Int(size.height)))"
            }
            let suffix = hasNotch(screen: screen) ? " — notch" : ""
            options.append(ScreenOption(id: id, name: name + suffix))
        }
        return options
    }
}
