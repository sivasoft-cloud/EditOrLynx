import SwiftUI

/// Continuous curvature pill shape (Apple squircle / G2 continuity)
/// supporting both attached notch surfaces and floating pills.
public struct PillShape: Shape, InsettableShape {
    public var topLeadingRadius: CGFloat
    public var topTrailingRadius: CGFloat
    public var bottomLeadingRadius: CGFloat
    public var bottomTrailingRadius: CGFloat
    public var outwardTopCorners: Bool
    public var topCutoutWidth: CGFloat
    public var topCutoutDepth: CGFloat
    public var topCutoutCornerRadius: CGFloat
    public var inset: CGFloat = 0

    public init(cornerRadius: CGFloat) {
        self.topLeadingRadius = cornerRadius
        self.topTrailingRadius = cornerRadius
        self.bottomLeadingRadius = cornerRadius
        self.bottomTrailingRadius = cornerRadius
        self.outwardTopCorners = false
        self.topCutoutWidth = 0
        self.topCutoutDepth = 0
        self.topCutoutCornerRadius = 0
        self.inset = 0
    }

    public init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topLeadingRadius = topCornerRadius
        self.topTrailingRadius = topCornerRadius
        self.bottomLeadingRadius = bottomCornerRadius
        self.bottomTrailingRadius = bottomCornerRadius
        self.outwardTopCorners = false
        self.topCutoutWidth = 0
        self.topCutoutDepth = 0
        self.topCutoutCornerRadius = 0
        self.inset = 0
    }

    public init(
        topLeadingRadius: CGFloat,
        topTrailingRadius: CGFloat,
        bottomLeadingRadius: CGFloat,
        bottomTrailingRadius: CGFloat,
        outwardTopCorners: Bool = false,
        topCutoutWidth: CGFloat = 0,
        topCutoutDepth: CGFloat = 0,
        topCutoutCornerRadius: CGFloat = 0,
        inset: CGFloat = 0
    ) {
        self.topLeadingRadius = topLeadingRadius
        self.topTrailingRadius = topTrailingRadius
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
        self.outwardTopCorners = outwardTopCorners
        self.topCutoutWidth = topCutoutWidth
        self.topCutoutDepth = topCutoutDepth
        self.topCutoutCornerRadius = topCutoutCornerRadius
        self.inset = inset
    }

    public var animatableData: AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<
            AnimatablePair<CGFloat, CGFloat>,
            AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>
        >
    > {
        get {
            AnimatablePair(
                AnimatablePair(topLeadingRadius, topTrailingRadius),
                AnimatablePair(
                    AnimatablePair(bottomLeadingRadius, bottomTrailingRadius),
                    AnimatablePair(topCutoutWidth, AnimatablePair(topCutoutDepth, topCutoutCornerRadius))
                )
            )
        }
        set {
            topLeadingRadius = newValue.first.first
            topTrailingRadius = newValue.first.second
            bottomLeadingRadius = newValue.second.first.first
            bottomTrailingRadius = newValue.second.first.second
            topCutoutWidth = newValue.second.second.first
            topCutoutDepth = newValue.second.second.second.first
            topCutoutCornerRadius = newValue.second.second.second.second
        }
    }

    public func inset(by amount: CGFloat) -> PillShape {
        var copy = self
        copy.inset += amount
        return copy
    }

    public func path(in rect: CGRect) -> Path {
        let insetRect = rect.insetBy(dx: inset, dy: inset)
        guard insetRect.width > 1 && insetRect.height > 1 else { return Path() }

        // If outward top corners are enabled (attached to the Mac screen top bezel),
        // render the continuous TopAttachedNotchShape with smooth G2 ear flairs
        if outwardTopCorners {
            let earR = max(topLeadingRadius, topTrailingRadius)
            let botR = max(bottomLeadingRadius, bottomTrailingRadius)
            return TopAttachedNotchShape(
                bottomRadius: botR,
                topEarRadius: earR,
                isDetached: false,
                inset: 0
            ).path(in: insetRect)
        }

        // Otherwise render continuous squircle (rounded rectangle)
        let maxRadius = min(insetRect.width, insetRect.height) / 2.0
        let botR = min(max(bottomLeadingRadius, bottomTrailingRadius), maxRadius)
        return RoundedRectangle(cornerRadius: botR, style: .continuous).path(in: insetRect)
    }
}
