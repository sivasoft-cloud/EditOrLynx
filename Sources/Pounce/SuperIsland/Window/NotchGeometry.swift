import AppKit

/// Clean, accurate notch and display geometry calculations based on macOS screen APIs.
public struct NotchGeometry: Equatable {
    public let screenFrame: CGRect
    public let hasPhysicalNotch: Bool
    public let physicalNotchSize: CGSize
    public let backingScale: CGFloat
    public let auxiliaryTopLeftArea: CGRect?
    public let auxiliaryTopRightArea: CGRect?

    public init(screen: NSScreen) {
        self.screenFrame = screen.frame
        self.backingScale = screen.backingScaleFactor

        if #available(macOS 12.0, *),
           let topLeft = screen.auxiliaryTopLeftArea,
           let topRight = screen.auxiliaryTopRightArea,
           screen.safeAreaInsets.top > 0 {
            self.hasPhysicalNotch = true
            self.auxiliaryTopLeftArea = topLeft
            self.auxiliaryTopRightArea = topRight

            // Exact hardware notch width between the left and right auxiliary menu areas
            let width = screen.frame.width - topLeft.width - topRight.width
            let height = screen.safeAreaInsets.top
            self.physicalNotchSize = CGSize(
                width: max(160, ceil(width)),
                height: max(30, ceil(height))
            )
        } else {
            self.hasPhysicalNotch = false
            self.auxiliaryTopLeftArea = nil
            self.auxiliaryTopRightArea = nil
            // Simulated / non-notch display default
            self.physicalNotchSize = CGSize(width: 200, height: 32)
        }
    }

    /// Hardware notch width on the target screen
    public var hardwareNotchWidth: CGFloat {
        physicalNotchSize.width
    }

    /// Hardware notch height on the target screen (typically 32 to 37 pt)
    public var hardwareNotchHeight: CGFloat {
        physicalNotchSize.height
    }

    /// The exact bounding rect of the hardware notch in AppKit screen coordinates
    public var hardwareNotchRect: CGRect? {
        guard hasPhysicalNotch, let topLeft = auxiliaryTopLeftArea else {
            return nil
        }
        let notchX = screenFrame.origin.x + topLeft.width
        let notchY = screenFrame.maxY - physicalNotchSize.height
        return CGRect(
            x: notchX,
            y: notchY,
            width: physicalNotchSize.width,
            height: physicalNotchSize.height
        )
    }

    /// Optimal compact island size that matches the camera housing perfectly
    public func compactIslandSize(horizontalInset: CGFloat = 0, heightInset: CGFloat = 0) -> CGSize {
        if hasPhysicalNotch {
            return CGSize(
                width: max(160, physicalNotchSize.width - (horizontalInset * 2)),
                height: max(28, physicalNotchSize.height - heightInset)
            )
        } else {
            return CGSize(width: 200, height: 32)
        }
    }

    /// Center anchor for the notch window on the given screen
    public var anchorPoint: CGPoint {
        if let notchRect = hardwareNotchRect {
            return CGPoint(x: notchRect.midX, y: notchRect.maxY)
        } else {
            return CGPoint(x: screenFrame.midX, y: screenFrame.maxY)
        }
    }

    /// Window frame calculation for a given content size, pinned to the top of the display
    public func windowFrame(for size: CGSize, topInset: CGFloat = 0) -> CGRect {
        let anchor = anchorPoint
        let x = anchor.x - (size.width / 2.0)
        let y = anchor.y - size.height - topInset
        // Pixel-align coordinates based on backingScale to prevent subpixel jitter
        let scale = max(1.0, backingScale)
        let alignedX = round(x * scale) / scale
        let alignedY = round(y * scale) / scale
        return CGRect(x: alignedX, y: alignedY, width: size.width, height: size.height)
    }
}
