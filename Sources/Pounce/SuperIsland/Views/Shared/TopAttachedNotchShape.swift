import SwiftUI
import CoreGraphics

/// Clean Apple-style continuous curvature corner generator.
/// Provides G2 curvature continuity (super-ellipse / squircle smoothing)
/// so corners seamlessly flow into straight edges without abrupt curvature transitions.
public enum ContinuousCurvature {

    /// Adds a G2 continuous smooth corner to a path.
    /// - Parameters:
    ///   - path: The target SwiftUI Path.
    ///   - corner: The virtual sharp corner point.
    ///   - from: Incoming normalized direction vector.
    ///   - to: Outgoing normalized direction vector.
    ///   - radius: The corner radius.
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

        // Apple squircle curvature smoothing factor
        // Corner extent along each straight edge:
        let extent = radius * 1.28
        let cp1Offset = radius * 0.44
        let cp2Offset = radius * 0.82

        // Start point along incoming edge
        let startPoint = CGPoint(
            x: corner.x - from.dx * extent,
            y: corner.y - from.dy * extent
        )

        // Control point 1 (tangent to incoming line)
        let control1 = CGPoint(
            x: corner.x - from.dx * (extent - cp1Offset),
            y: corner.y - from.dy * (extent - cp1Offset)
        )

        // End point along outgoing edge
        let endPoint = CGPoint(
            x: corner.x + to.dx * extent,
            y: corner.y + to.dy * extent
        )

        // Control point 2 (tangent to outgoing line)
        let control2 = CGPoint(
            x: corner.x + to.dx * (extent - cp2Offset),
            y: corner.y + to.dy * (extent - cp2Offset)
        )

        // Connecting line up to the curve start
        path.addLine(to: startPoint)

        // Cubic Bézier curve with progressive G2 curvature
        path.addCurve(to: endPoint, control1: control1, control2: control2)
    }

    /// Adds an outward concave fillet (ear) connecting a vertical notch edge to the top display bezel.
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

        // Concave curve flaring out into the top bezel
        let extent = radius * 1.25
        let startPoint = CGPoint(
            x: corner.x - from.dx * extent,
            y: corner.y - from.dy * extent
        )
        let endPoint = CGPoint(
            x: corner.x + to.dx * extent,
            y: corner.y + to.dy * extent
        )

        let control1 = CGPoint(
            x: corner.x - from.dx * (extent * 0.45),
            y: corner.y - from.dy * (extent * 0.45)
        )
        let control2 = CGPoint(
            x: corner.x + to.dx * (extent * 0.45),
            y: corner.y + to.dy * (extent * 0.45)
        )

        path.addLine(to: startPoint)
        path.addCurve(to: endPoint, control1: control1, control2: control2)
    }
}

/// An authentic native MacBook notch shape with continuous curvature (G2 squircle)
/// that attaches seamlessly to the top bezel of the display or floats when detached.
public struct TopAttachedNotchShape: Shape, InsettableShape {
    public var bottomRadius: CGFloat
    public var topEarRadius: CGFloat
    public var isDetached: Bool
    public var inset: CGFloat

    public init(
        bottomRadius: CGFloat = 19,
        topEarRadius: CGFloat = 12,
        isDetached: Bool = false,
        inset: CGFloat = 0
    ) {
        self.bottomRadius = bottomRadius
        self.topEarRadius = topEarRadius
        self.isDetached = isDetached
        self.inset = inset
    }

    public var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(bottomRadius, topEarRadius) }
        set {
            bottomRadius = newValue.first
            topEarRadius = newValue.second
        }
    }

    public func inset(by amount: CGFloat) -> TopAttachedNotchShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        guard insetRect.width > 1 && insetRect.height > 1 else {
            return Path()
        }

        // If floating/detached (non-notched display or user preference), render continuous squircle
        if isDetached {
            let maxRadius = min(insetRect.width, insetRect.height) / 2.0
            let r = min(bottomRadius, maxRadius)
            return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: insetRect)
        }

        var path = Path()

        let bRadius = min(bottomRadius, insetRect.height / 2.0, insetRect.width / 4.0)
        let eRadius = min(topEarRadius, insetRect.height / 3.0, insetRect.width / 4.0)

        // 1. Move to start at the top bezel before the right ear
        let topY = insetRect.minY
        let minX = insetRect.minX
        let maxX = insetRect.maxX
        let maxY = insetRect.maxY

        // Top line across the notch between left ear and right ear
        path.move(to: CGPoint(x: minX, y: topY))
        path.addLine(to: CGPoint(x: maxX - eRadius, y: topY))

        // 2. Top-right outward ear flaring down into the right wall
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: maxX, y: topY),
            from: CGVector(dx: -1, dy: 0),
            to: CGVector(dx: 0, dy: 1),
            radius: eRadius
        )

        // 3. Right wall down
        path.addLine(to: CGPoint(x: maxX, y: maxY - bRadius))

        // 4. Bottom-right inward continuous corner
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: maxX, y: maxY),
            from: CGVector(dx: 0, dy: 1),
            to: CGVector(dx: -1, dy: 0),
            radius: bRadius
        )

        // 5. Bottom edge across to bottom-left
        path.addLine(to: CGPoint(x: minX + bRadius, y: maxY))

        // 6. Bottom-left inward continuous corner
        ContinuousCurvature.addCorner(
            to: &path,
            corner: CGPoint(x: minX, y: maxY),
            from: CGVector(dx: -1, dy: 0),
            to: CGVector(dx: 0, dy: -1),
            radius: bRadius
        )

        // 7. Left wall up
        path.addLine(to: CGPoint(x: minX, y: topY + eRadius))

        // 8. Top-left outward ear flaring into the top bezel
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

/// Unified notch body shape that automatically picks top-attached or detached continuous squircle
public struct NotchBodyShape: Shape, InsettableShape {
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

    public func inset(by amount: CGFloat) -> NotchBodyShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        if isAttachedToTop {
            return TopAttachedNotchShape(
                bottomRadius: cornerRadius,
                topEarRadius: earRadius,
                isDetached: false,
                inset: inset
            ).path(in: rect)
        } else {
            let insetRect = rect.insetBy(dx: inset, dy: inset)
            let r = min(cornerRadius, min(insetRect.width, insetRect.height) / 2.0)
            return RoundedRectangle(cornerRadius: r, style: .continuous).path(in: insetRect)
        }
    }
}
