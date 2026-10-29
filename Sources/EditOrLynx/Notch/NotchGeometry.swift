import AppKit

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
            self.physicalNotchSize = CGSize(width: 200, height: 32)
        }
    }

    public var hardwareNotchWidth: CGFloat {
        physicalNotchSize.width
    }

    public var hardwareNotchHeight: CGFloat {
        physicalNotchSize.height
    }

    public var hardwareNotchRect: CGRect? {
        guard hasPhysicalNotch, let topLeft = auxiliaryTopLeftArea else { return nil }
        let notchX = screenFrame.origin.x + topLeft.width
        let notchY = screenFrame.maxY - physicalNotchSize.height
        return CGRect(x: notchX, y: notchY, width: physicalNotchSize.width, height: physicalNotchSize.height)
    }

    public func compactIslandSize(horizontalPadding: CGFloat = 0) -> CGSize {
        if hasPhysicalNotch {
            return CGSize(
                width: max(160, physicalNotchSize.width + horizontalPadding),
                height: physicalNotchSize.height
            )
        } else {
            return CGSize(width: 210, height: 32)
        }
    }

    public var anchorPoint: CGPoint {
        if let notchRect = hardwareNotchRect {
            return CGPoint(x: notchRect.midX, y: notchRect.maxY)
        } else {
            return CGPoint(x: screenFrame.midX, y: screenFrame.maxY)
        }
    }

    public func windowFrame(for size: CGSize, topOffset: CGFloat = 0) -> CGRect {
        let anchor = anchorPoint
        let x = anchor.x - (size.width / 2.0)
        let y = anchor.y - size.height - topOffset
        let scale = max(1.0, backingScale)
        let alignedX = round(x * scale) / scale
        let alignedY = round(y * scale) / scale
        return CGRect(x: alignedX, y: alignedY, width: size.width, height: size.height)
    }
}
