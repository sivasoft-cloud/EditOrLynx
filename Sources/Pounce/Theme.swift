import SwiftUI
import AppKit
import PounceCore

/// The accent the person picked for the app and its notch.
/// `system` follows the Mac's own highlight colour, the way a native app does.
enum AccentChoice: String, CaseIterable, Identifiable {
    case blue
    case system
    case purple
    case red
    case orange
    case yellow
    case green
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .blue: return "Blue (Default)"
        case .system: return "System"
        case .purple: return "Purple"
        case .red: return "Red"
        case .orange: return "Orange"
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .graphite: return "Graphite"
        }
    }

    /// The Mac system colours, so a picked accent still looks native in both appearances.
    var color: Color? {
        switch self {
        case .system: return nil
        case .blue: return Color(hex: 0x0A84FF)
        case .purple: return Color(hex: 0xBF5AF2)
        case .red: return Color(hex: 0xFF453A)
        case .orange: return Color(hex: 0xFF9F0A)
        case .yellow: return Color(hex: 0xFFD60A)
        case .green: return Color(hex: 0x30D158)
        case .graphite: return Color(hex: 0x9A9AA0)
        }
    }

    /// Text or glyph ink that stays readable on top of the accent.
    var ink: Color {
        switch self {
        case .yellow, .green, .graphite: return Color.black.opacity(0.82)
        default: return .white
        }
    }
}

enum AccentStore {
    static var choice: AccentChoice = .blue
    static var picked: Color? { choice.color ?? Color(hex: 0x0A84FF) }
}

enum Pal {
    static let bg = adaptive(light: 0xF8F9FC, dark: 0x090A0D)
    static let bgLift = adaptive(light: 0xFFFFFF, dark: 0x101217)
    static let sidebar = adaptive(light: 0xF0F2F8, dark: 0x0D0E13)
    static let panel = adaptive(light: 0xFFFFFF, dark: 0x14161F)
    static let elevated = adaptive(light: 0xF2F4FA, dark: 0x1A1D28)
    static let elevated2 = adaptive(light: 0xE8ECF4, dark: 0x222634)
    /// A recessed surface: dark in both appearances, but much softer in light.
    static let recess = adaptive(light: 0xEAEDF5, dark: 0x050608)
    static let stroke = veil(0.08)
    static let strokeStrong = veil(0.16)
    static let text = adaptive(light: 0x14151B, dark: 0xF6F7FA)
    static let secondary = adaptive(light: 0x626574, dark: 0x9699A7)
    static let tertiary = adaptive(light: 0x8E92A2, dark: 0x606373)
    static var accent: Color { AccentStore.picked ?? adaptive(light: 0x0A84FF, dark: 0x54A6FF) }
    static var accentSoft: Color { AccentStore.picked ?? adaptive(light: 0x3B82F6, dark: 0x60A5FA) }
    static var accentDeep: Color { AccentStore.picked ?? adaptive(light: 0x1D4ED8, dark: 0x2563EB) }
    static var accentText: Color { AccentStore.picked ?? adaptive(light: 0x1E40AF, dark: 0x93C5FD) }
    /// The notch, toggles and segmented pickers: the chosen accent, or the Mac's when set to System.
    static var systemAccent: Color { AccentStore.picked ?? Color(nsColor: .controlAccentColor) }
    /// Ink for text and glyphs sitting on the accent fill.
    static var onAccent: Color { AccentStore.choice.ink }
    static let green = adaptive(light: 0x138848, dark: 0x32D768)
    static let blue = adaptive(light: 0x246BD0, dark: 0x54A6FF)
    static let purple = adaptive(light: 0x7656D4, dark: 0xB58BFF)
    static let red = adaptive(light: 0xD04238, dark: 0xFF5D54)

    /// Resolves to a light or dark hex at draw time, so windows can change appearance live.
    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(hex: appearance.isDark ? dark : light)
        })
    }

    /// Contrasting overlay: white ink on dark, black ink on light.
    static func veil(_ opacity: Double) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            NSColor(white: appearance.isDark ? 1 : 0, alpha: opacity)
        })
    }
}

extension NSAppearance {
    var isDark: Bool {
        bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

enum Typo {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded)
    }

    static func body(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }

    static func mono(_ size: CGFloat, _ weight: Font.Weight = .medium) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

struct PounceMark: View {
    var size: CGFloat = 28
    var glow: Bool = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x3E424C), Color(hex: 0x22242A), Color(hex: 0x14161A)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color.white.opacity(0.25), Pal.systemAccent.opacity(0.3), Color.white.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: max(0.6, size * 0.025)
                        )
                )
                .shadow(color: glow ? Pal.systemAccent.opacity(0.32) : Color.black.opacity(0.3), radius: size * 0.28, y: 2)

            // Top camera notch inset
            Capsule()
                .fill(Color(hex: 0x050608))
                .frame(width: size * 0.44, height: size * 0.13)
                .offset(y: -size * 0.29)

            // Downward arrow with crisp gradient
            Image(systemName: "arrow.down")
                .font(.system(size: size * 0.45, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.white, Pal.systemAccent],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .offset(y: size * 0.04)
        }
        .frame(width: size, height: size)
    }
}

/// The notch glyph: a plain SF Symbol, the way a system control would draw it.
struct NotchMark: View {
    var size: CGFloat = 12
    var weight: Font.Weight = .semibold
    var tint: Color = .white

    var body: some View {
        Image(systemName: "arrow.down")
            .font(.system(size: size, weight: weight))
            .foregroundStyle(tint)
            .frame(width: size * 1.2, height: size * 1.2)
    }
}

/// The small flag that marks a plan-locked option.
struct ProFlag: View {
    var body: some View {
        Text("PRO")
            .font(Typo.body(6.5, .bold))
            .tracking(0.4)
            .foregroundStyle(Color.white)
            .padding(.horizontal, 4.5)
            .padding(.vertical, 1.5)
            .background(Pal.accentDeep.opacity(0.95), in: Capsule())
            .padding(4)
    }
}

/// One accent dot in Settings: the system colour plus the Mac's own palette.
struct AccentSwatch: View {
    var choice: AccentChoice
    var selected: Bool
    var action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(choice.color ?? Color(nsColor: .controlAccentColor))
                if choice == .system {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(choice.ink)
                }
            }
            .frame(width: 19, height: 19)
            .overlay(Circle().strokeBorder(Color.black.opacity(0.18), lineWidth: 0.6))
            .overlay(
                Circle()
                    .strokeBorder(selected ? Pal.text.opacity(0.6) : Color.clear, lineWidth: 1.4)
                    .padding(-3)
            )
            .scaleEffect(hovering ? 1.1 : 1)
        }
        .buttonStyle(.plain)
        .onHover { value in
            withAnimation(.easeOut(duration: 0.12)) { hovering = value }
        }
        .help(choice.title)
        .accessibilityLabel(choice.title)
    }
}

/// A small circular plate for the notch glyph, matching the weight of system toolbar icons.
struct NotchBadge: View {
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.09))
            Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.5)
            NotchMark(size: size * 0.42)
        }
        .frame(width: size, height: size)
    }
}

struct FilmThumb: View {
    var seed: Int = 0
    var kind: DownloadKind = .video
    var size: CGFloat = 52
    var corner: CGFloat = 12
    var showBadge: Bool = true

    /// Neutral graphite tiles with a whisper of hue, the way Finder draws a generic file.
    private var palette: [Color] {
        let sets: [[UInt32]] = [
            [0x3B3F47, 0x1B1D21],
            [0x37393F, 0x191A1E],
            [0x3D3A3E, 0x1E1C1F],
            [0x363B3B, 0x1A1D1D]
        ]
        let colors = sets[abs(seed) % sets.count]
        return colors.map { Color(hex: $0) }
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .top, endPoint: .bottom)
            Image(systemName: kind.symbol)
                .font(.system(size: size * 0.3, weight: .regular))
                .foregroundStyle(Color.white.opacity(0.72))
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.7)
        )
        .overlay(alignment: .bottomTrailing) {
            if showBadge {
                Text(kind == .clip ? "CLIP" : kind.displayName.uppercased())
                    .font(.system(size: max(6, size * 0.13), weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                    .padding(.horizontal, size * 0.07)
                    .padding(.vertical, size * 0.035)
                    .background(Color.black.opacity(0.45), in: Capsule())
                    .padding(size * 0.07)
            }
        }
    }
}

struct LegacyThemePillShape: Shape {
    var topLeadingRadius: CGFloat
    var topTrailingRadius: CGFloat
    var bottomLeadingRadius: CGFloat
    var bottomTrailingRadius: CGFloat
    var outwardTopCorners: Bool
    var topCutoutWidth: CGFloat
    var topCutoutDepth: CGFloat
    var topCutoutCornerRadius: CGFloat

    init(cornerRadius: CGFloat) {
        self.topLeadingRadius = cornerRadius
        self.topTrailingRadius = cornerRadius
        self.bottomLeadingRadius = cornerRadius
        self.bottomTrailingRadius = cornerRadius
        self.outwardTopCorners = false
        self.topCutoutWidth = 0
        self.topCutoutDepth = 0
        self.topCutoutCornerRadius = 0
    }

    init(topCornerRadius: CGFloat, bottomCornerRadius: CGFloat) {
        self.topLeadingRadius = topCornerRadius
        self.topTrailingRadius = topCornerRadius
        self.bottomLeadingRadius = bottomCornerRadius
        self.bottomTrailingRadius = bottomCornerRadius
        self.outwardTopCorners = false
        self.topCutoutWidth = 0
        self.topCutoutDepth = 0
        self.topCutoutCornerRadius = 0
    }

    init(bottomRadius: CGFloat, topRadius: CGFloat = 0, outwardTopCorners: Bool = false) {
        self.topLeadingRadius = topRadius
        self.topTrailingRadius = topRadius
        self.bottomLeadingRadius = bottomRadius
        self.bottomTrailingRadius = bottomRadius
        self.outwardTopCorners = outwardTopCorners
        self.topCutoutWidth = 0
        self.topCutoutDepth = 0
        self.topCutoutCornerRadius = 0
    }

    init(
        topLeadingRadius: CGFloat,
        topTrailingRadius: CGFloat,
        bottomLeadingRadius: CGFloat,
        bottomTrailingRadius: CGFloat,
        outwardTopCorners: Bool = false,
        topCutoutWidth: CGFloat = 0,
        topCutoutDepth: CGFloat = 0,
        topCutoutCornerRadius: CGFloat = 0
    ) {
        self.topLeadingRadius = topLeadingRadius
        self.topTrailingRadius = topTrailingRadius
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
        self.outwardTopCorners = outwardTopCorners
        self.topCutoutWidth = topCutoutWidth
        self.topCutoutDepth = topCutoutDepth
        self.topCutoutCornerRadius = topCutoutCornerRadius
    }

    var animatableData: CGFloat {
        get { bottomLeadingRadius }
        set {
            bottomLeadingRadius = newValue
            bottomTrailingRadius = newValue
        }
    }

    func path(in rect: CGRect) -> Path {
        let maxOuterRadius = min(rect.width, rect.height) / 2
        let topLeading = min(topLeadingRadius, maxOuterRadius)
        let topTrailing = min(topTrailingRadius, maxOuterRadius)
        let bottomLeading = min(bottomLeadingRadius, maxOuterRadius)
        let bottomTrailing = min(bottomTrailingRadius, maxOuterRadius)
        let cutoutWidth = min(max(topCutoutWidth, 0), max(0, rect.width - 24))
        let cutoutDepth = min(max(topCutoutDepth, 0), max(0, rect.height - 8))
        let cutoutRadius = min(topCutoutCornerRadius, cutoutDepth, cutoutWidth / 2)
        let hasCutout = cutoutWidth > 0 && cutoutDepth > 0

        if outwardTopCorners && !hasCutout {
            return outwardTopCornerPath(
                in: rect,
                topLeading: topLeading,
                topTrailing: topTrailing,
                bottomLeading: bottomLeading,
                bottomTrailing: bottomTrailing
            )
        }

        var path = Path()
        path.move(to: CGPoint(x: rect.minX + topLeading, y: rect.minY))

        if hasCutout {
            let cutoutMinX = rect.midX - (cutoutWidth / 2)
            let cutoutMaxX = rect.midX + (cutoutWidth / 2)

            path.addLine(to: CGPoint(x: cutoutMinX, y: rect.minY))
            path.addLine(to: CGPoint(x: cutoutMinX, y: rect.minY + cutoutDepth - cutoutRadius))

            if cutoutRadius > 0 {
                path.addArc(
                    center: CGPoint(
                        x: cutoutMinX + cutoutRadius,
                        y: rect.minY + cutoutDepth - cutoutRadius
                    ),
                    radius: cutoutRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(90),
                    clockwise: true
                )
            }

            path.addLine(to: CGPoint(x: cutoutMaxX - cutoutRadius, y: rect.minY + cutoutDepth))

            if cutoutRadius > 0 {
                path.addArc(
                    center: CGPoint(
                        x: cutoutMaxX - cutoutRadius,
                        y: rect.minY + cutoutDepth - cutoutRadius
                    ),
                    radius: cutoutRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(0),
                    clockwise: true
                )
            }

            path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
        } else {
            path.addLine(to: CGPoint(x: rect.maxX - topTrailing, y: rect.minY))
        }

        if topTrailing > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - topTrailing, y: rect.minY + topTrailing),
                radius: topTrailing,
                startAngle: .degrees(-90),
                endAngle: .degrees(0),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomTrailing))

        if bottomTrailing > 0 {
            path.addArc(
                center: CGPoint(x: rect.maxX - bottomTrailing, y: rect.maxY - bottomTrailing),
                radius: bottomTrailing,
                startAngle: .degrees(0),
                endAngle: .degrees(90),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY))

        if bottomLeading > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + bottomLeading, y: rect.maxY - bottomLeading),
                radius: bottomLeading,
                startAngle: .degrees(90),
                endAngle: .degrees(180),
                clockwise: false
            )
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeading))

        if topLeading > 0 {
            path.addArc(
                center: CGPoint(x: rect.minX + topLeading, y: rect.minY + topLeading),
                radius: topLeading,
                startAngle: .degrees(180),
                endAngle: .degrees(270),
                clockwise: false
            )
        }

        path.closeSubpath()
        return path
    }

    private func outwardTopCornerPath(
        in rect: CGRect,
        topLeading: CGFloat,
        topTrailing: CGFloat,
        bottomLeading: CGFloat,
        bottomTrailing: CGFloat
    ) -> Path {
        var path = Path()
        let leftWallX = rect.minX + topLeading
        let rightWallX = rect.maxX - topTrailing

        path.move(to: CGPoint(x: rect.minX, y: rect.minY))

        if topLeading > 0 {
            path.addQuadCurve(
                to: CGPoint(x: leftWallX, y: rect.minY + topLeading),
                control: CGPoint(x: leftWallX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: leftWallX, y: rect.minY))
        }

        path.addLine(to: CGPoint(x: leftWallX, y: rect.maxY - bottomLeading))

        if bottomLeading > 0 {
            path.addQuadCurve(
                to: CGPoint(x: leftWallX + bottomLeading, y: rect.maxY),
                control: CGPoint(x: leftWallX, y: rect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: leftWallX, y: rect.maxY))
        }

        path.addLine(to: CGPoint(x: rightWallX - bottomTrailing, y: rect.maxY))

        if bottomTrailing > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rightWallX, y: rect.maxY - bottomTrailing),
                control: CGPoint(x: rightWallX, y: rect.maxY)
            )
        } else {
            path.addLine(to: CGPoint(x: rightWallX, y: rect.maxY))
        }

        path.addLine(to: CGPoint(x: rightWallX, y: rect.minY + topTrailing))

        if topTrailing > 0 {
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY),
                control: CGPoint(x: rightWallX, y: rect.minY)
            )
        } else {
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

typealias NotchShape = PillShape

struct CircleIconButton: View {
    var symbol: String
    var size: CGFloat = 28
    var tint: Color = Pal.secondary
    var help: String = ""
    var action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size * 0.44, weight: .semibold))
                .foregroundStyle(hovering ? Pal.text : tint)
                .frame(width: size, height: size)
                .background(
                    Circle()
                        .fill(hovering ? Pal.veil(0.12) : Pal.veil(0.04))
                )
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(hovering ? 0.16 : 0.05), lineWidth: 0.6)
                )
                .scaleEffect(pressed ? 0.92 : (hovering ? 1.05 : 1.0))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .onHover { hovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { pressed = false } }
        )
        .help(help)
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: hovering)
    }
}

struct SoftButton: View {
    var title: String
    var symbol: String? = nil
    var accent: Bool = false
    var action: () -> Void

    @State private var hovering = false
    @State private var pressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol {
                    Image(systemName: symbol)
                        .font(.system(size: 11, weight: .semibold))
                }
                Text(title)
                    .font(Typo.body(12, .semibold))
            }
            .foregroundStyle(accent ? Color.black.opacity(0.88) : (hovering ? Pal.text : Pal.secondary))
            .padding(.horizontal, 13)
            .frame(height: 30)
            .background(
                Capsule()
                    .fill(accent ? AnyShapeStyle(LinearGradient(colors: [Pal.accentSoft, Pal.accent], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(hovering ? Pal.elevated2 : Pal.elevated))
            )
            .overlay(
                Capsule().strokeBorder(accent ? Color.white.opacity(0.24) : (hovering ? Pal.strokeStrong : Pal.stroke), lineWidth: 0.8)
            )
            .scaleEffect(pressed ? 0.95 : (hovering ? 1.02 : 1.0))
            .shadow(color: accent ? Pal.accent.opacity(0.25) : .clear, radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .noFocusOutline()
        .onHover { hovering = $0 }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in withAnimation(.easeOut(duration: 0.08)) { pressed = true } }
                .onEnded { _ in withAnimation(.spring(response: 0.28, dampingFraction: 0.6)) { pressed = false } }
        )
        .animation(.spring(response: 0.24, dampingFraction: 0.76), value: hovering)
    }
}

struct SegmentedPills<T: Hashable>: View {
    var options: [(T, String, String?)]
    @Binding var selection: T
    var accent: Bool = true

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.0) { option in
                let selected = option.0 == selection
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                        selection = option.0
                    }
                } label: {
                    VStack(spacing: 1) {
                        Text(option.1)
                            .font(Typo.body(11.5, .semibold))
                        if let sub = option.2 {
                            Text(sub)
                                .font(Typo.body(9, .medium))
                                .opacity(0.65)
                        }
                    }
                    .foregroundStyle(selected ? (accent ? Color.white : Pal.text) : Pal.secondary)
                    .frame(maxWidth: .infinity)
                    .frame(height: option.2 == nil ? 28 : 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selected ? (accent ? Pal.systemAccent : Pal.elevated2) : Color.clear)
                    )
                    .shadow(color: selected && accent ? Pal.systemAccent.opacity(0.28) : .clear, radius: 4, y: 1)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Pal.recess)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }
}

struct ThinProgress: View {
    /// A negative value means "size unknown": a travelling bar instead of a fake percentage.
    var progress: Double
    var height: CGFloat = 4
    var tint: Color = Pal.systemAccent
    var animated: Bool = true
    @State private var phase: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Pal.veil(0.08))

                if progress < 0 {
                    if animated {
                        Capsule()
                            .fill(
                                LinearGradient(colors: [tint.opacity(0.2), tint, tint.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            )
                            .frame(width: max(height * 4, geo.size.width * 0.35))
                            .offset(x: (geo.size.width - geo.size.width * 0.35) * phase)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) { phase = 1 }
                            }
                            .onDisappear { phase = 0 }
                    } else {
                        Capsule()
                            .fill(tint.opacity(0.3))
                            .frame(width: geo.size.width * 0.25)
                    }
                } else {
                    let clamped = min(1, max(0, progress))
                    let targetWidth = max(height, geo.size.width * clamped)

                    ZStack(alignment: .trailing) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [tint.opacity(0.78), tint],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        if clamped > 0.02 && clamped < 0.99 && animated {
                            Circle()
                                .fill(Color.white.opacity(0.9))
                                .frame(width: height + 1, height: height + 1)
                                .blur(radius: 0.5)
                        }
                    }
                    .frame(width: targetWidth)
                    .shadow(color: tint.opacity(0.35), radius: 3, x: 0, y: 1)
                    .animation(.spring(response: 0.35, dampingFraction: 0.78), value: progress)
                }
            }
        }
        .frame(height: height)
    }
}

struct Sparkline: View {
    var samples: [Double]
    var tint: Color = Pal.accent

    var body: some View {
        Canvas { context, size in
            guard samples.count > 1 else { return }
            let maxValue = max(1, samples.max() ?? 1)
            var path = Path()
            for (index, sample) in samples.enumerated() {
                let x = size.width * CGFloat(index) / CGFloat(samples.count - 1)
                let y = size.height - (CGFloat(sample / maxValue) * (size.height - 2)) - 1
                if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            context.stroke(path, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.4), tint]),
                startPoint: .zero,
                endPoint: CGPoint(x: size.width, y: 0)
            ), lineWidth: 1.4)

            var fill = path
            fill.addLine(to: CGPoint(x: size.width, y: size.height))
            fill.addLine(to: CGPoint(x: 0, y: size.height))
            fill.closeSubpath()
            context.fill(fill, with: .linearGradient(
                Gradient(colors: [tint.opacity(0.2), tint.opacity(0.01)]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: 0, y: size.height)
            ))
        }
    }
}

struct Equalizer: View {
    var playing: Bool
    var tint: Color = Pal.accent
    var bars: Int = 4

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !playing)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<bars, id: \.self) { index in
                    let value = playing
                        ? 0.25 + 0.75 * abs(sin(t * (3.0 + Double(index) * 0.7) + Double(index) * 1.2))
                        : 0.2
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint, tint.opacity(0.65)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 2.5, height: max(3, 14 * value))
                        .shadow(color: playing ? tint.opacity(0.35) : .clear, radius: 1)
                }
            }
            .frame(height: 14, alignment: .bottom)
        }
    }
}

struct PounceSpectrogramFallbackView: View {
    var playing: Bool
    var barCount: Int = 24
    var height: CGFloat = 16

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.08, paused: !playing)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 1.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let ratio = Double(index) / Double(barCount)
                    let base = 1.0 - ratio * 0.45
                    let value = playing
                        ? max(0.12, base * abs(sin(t * (2.8 + Double(index) * 0.4) + Double(index) * 0.85)))
                        : 0.1
                    RoundedRectangle(cornerRadius: 1)
                        .fill(
                            Color(
                                hue: 0.58 + ratio * 0.15,
                                saturation: 0.85,
                                brightness: 0.95
                            )
                        )
                        .frame(width: 2.2, height: max(2, height * CGFloat(value)))
                }
            }
            .frame(height: height, alignment: .bottom)
        }
    }
}

struct ToggleSwitch: View {
    @Binding var isOn: Bool
    var tint: Color = Pal.systemAccent

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) { isOn.toggle() }
        } label: {
            Capsule()
                .fill(isOn ? tint : Pal.veil(0.14))
                .frame(width: 36, height: 21)
                .overlay(
                    Capsule()
                        .strokeBorder(Color.white.opacity(isOn ? 0.25 : 0.08), lineWidth: 0.8)
                )
                .overlay(alignment: isOn ? .trailing : .leading) {
                    Circle()
                        .fill(Color.white)
                        .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
                        .frame(width: 17, height: 17)
                        .padding(2)
                }
                .shadow(color: isOn ? tint.opacity(0.35) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

struct KeyCap: View {
    var text: String

    var body: some View {
        Text(text)
            .font(Typo.body(10, .semibold))
            .foregroundStyle(Pal.tertiary)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Pal.veil(0.06), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct SectionLabel: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(text.uppercased())
                .font(Typo.body(10, .semibold))
                .tracking(0.7)
                .foregroundStyle(Pal.tertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(Typo.body(10.5, .medium))
                    .foregroundStyle(Pal.tertiary)
            }
        }
    }
}

// MARK: - Compatibility

extension View {
    @ViewBuilder
    func compatScrollIndicatorsHidden() -> some View {
        if #available(macOS 13.0, *) {
            self.scrollIndicators(.hidden)
        } else {
            self
        }
    }

    @ViewBuilder
    func noFocusOutline() -> some View {
        if #available(macOS 14.0, *) {
            self.focusable(false)
                .focusEffectDisabled()
        } else {
            self.focusable(false)
        }
    }

    @ViewBuilder
    func noFocusRing() -> some View {
        if #available(macOS 14.0, *) {
            self.focusEffectDisabled()
        } else {
            self
        }
    }
}

