import SwiftUI
import CoreGraphics

public enum ContinuousCurvature {
    /// Adds a G2 continuous smooth corner using Apple's squircle formula
    public static func addCorner(
        to path: inout Path,
        corner: CGPoint,
        from: CGVector,
        to: CGVector,
        radius: CGFloat
    ) {
        guard radius > 0.5 else {
            path.addLine(to: corner)
            return
        }

        let extent = radius * 1.28
        let cp1Offset = radius * 0.44
        let cp2Offset = radius * 0.82

        let startPoint = CGPoint(
            x: corner.x - from.dx * extent,
            y: corner.y - from.dy * extent
        )
        let control1 = CGPoint(
            x: corner.x - from.dx * (extent - cp1Offset),
            y: corner.y - from.dy * (extent - cp1Offset)
        )
        let endPoint = CGPoint(
            x: corner.x + to.dx * extent,
            y: corner.y + to.dy * extent
        )
        let control2 = CGPoint(
            x: corner.x + to.dx * (extent - cp2Offset),
            y: corner.y + to.dy * (extent - cp2Offset)
        )

        path.addLine(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
    }

    /// Adds an outward concave fillet (ear) connecting vertical notch walls to the screen bezel
    public static func addOutwardEar(
        to path: inout Path,
        corner: CGPoint,
        from: CGVector,
        to: CGVector,
        radius: CGFloat
    ) {
        guard radius > 0.5 else {
            path.addLine(to: corner)
            return
        }

        let extent = radius * 1.25
        let startPoint = CGPoint(x: corner.x - from.dx * extent, y: corner.y - from.dy * extent)
        let endPoint = CGPoint(x: corner.x + to.dx * extent, y: corner.y + to.dy * extent)
        let control1 = CGPoint(x: corner.x - from.dx * (extent * 0.45), y: corner.y - from.dy * (extent * 0.45))
        let control2 = CGPoint(x: corner.x + to.dx * (extent * 0.45), y: corner.y + to.dy * (extent * 0.45))

        path.addLine(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
    }
}

/// Authentic Top-Attached Notch Shape with Apple G2 continuous squircle and outward ear flairs
public struct NotchShape: Shape, InsettableShape {
    public var cornerRadius: CGFloat
    public var earRadius: CGFloat
    public var isAttachedToTop: Bool
    public var inset: CGFloat

    public init(
        cornerRadius: CGFloat = 19,
        earRadius: CGFloat = 12,
        isAttachedToTop: Bool = true,
        inset: CGFloat = 0
    ) {
        self.cornerRadius = cornerRadius
        self.earRadius = earRadius
        self.isAttachedToTop = isAttachedToTop
        self.inset = inset
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(cornerRadius, earRadius) }
        set {
            cornerRadius = newValue.first
            earRadius = newValue.second
        }
    }

    public func inset(by amount: CGFloat) -> NotchShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        guard insetRect.width > 1 && insetRect.height > 1 else { return Path() }

        if !isAttachedToTop {
            let maxRadius = min(insetRect.width, insetRect.height) / 2.0
            return RoundedRectangle(cornerRadius: min(cornerRadius, maxRadius), style: .continuous).path(in: insetRect)
        }

        var path = Path()
        let bRadius = min(cornerRadius, insetRect.height / 2.0, insetRect.width / 4.0)
        let eRadius = min(earRadius, insetRect.height / 3.0, insetRect.width / 4.0)

        let topY = insetRect.minY
        let minX = insetRect.minX
        let maxX = insetRect.maxX
        let maxY = insetRect.maxY

        // Top line
        path.move(to: CGPoint(x: minX, y: topY))
        path.addLine(to: CGPoint(x: maxX - eRadius, y: topY))

        // Right ear flaring down into right wall
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: maxX, y: topY),
            from: CGVector(dx: -1, dy: 0),
            to: CGVector(dx: 0, dy: 1),
            radius: eRadius
        )

        // Right wall
        path.addLine(to: CGPoint(x: maxX, y: maxY - bRadius))

        // Bottom right G2 squircle corner
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: maxX, y: maxY),
            from: CGVector(dx: 0, dy: 1),
            to: CGVector(dx: -1, dy: 0),
            radius: bRadius
        )

        // Bottom edge
        path.addLine(to: CGPoint(x: minX + bRadius, y: maxY))

        // Bottom left G2 squircle corner
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: minX, y: maxY),
            from: CGVector(dx: -1, dy: 0),
            to: CGVector(dx: 0, dy: -1),
            radius: bRadius
        )

        // Left wall
        path.addLine(to: CGPoint(x: minX, y: topY + eRadius))

        // Left ear flaring out to top bezel
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: minX, y: topY),
            from: CGVector(dx: 0, dy: -1),
            to: CGVector(dx: 1, dy: 0),
            radius: eRadius
        )

        path.closeSubpath()
        return path
    }
}
