import SwiftUI
import AppKit

public enum NotchMascotType: String, CaseIterable, Identifiable {
    case disabled = "disabled"
    case jelly = "jelly"
    case cat = "cat"
    case ghost = "ghost"
    case spark = "spark"
    case panda = "panda"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .disabled: return "Disabled (None)"
        case .jelly: return "Jelly Blob (Puff)"
        case .cat: return "Cyber Neko (Cat)"
        case .ghost: return "Cosmic Ghost"
        case .spark: return "Retro Spark"
        case .panda: return "Zen Panda"
        }
    }

    public var subtitle: String {
        switch self {
        case .disabled: return "Hide companion and keep notch clean & minimal"
        case .jelly: return "Spring-physics blob that gazes at cursor and squishes"
        case .cat: return "Animated feline with blinking eyes & twitching ears"
        case .ghost: return "Floating astral spirit with sinusoidal cosmic glow"
        case .spark: return "8-bit retro arcade spark bouncing to beats"
        case .panda: return "Cozy sleeping buddy with blushing cheeks"
        }
    }

    public var icon: String {
        switch self {
        case .disabled: return "slash.circle"
        case .jelly: return "drop.fill"
        case .cat: return "cat.fill"
        case .ghost: return "waveform.path.ecg"
        case .spark: return "bolt.fill"
        case .panda: return "heart.fill"
        }
    }
}

public struct NotchMascotView: View {
    public let size: CGFloat
    @AppStorage("notchMascotChoice") private var mascotChoice: String = "jelly"

    public init(size: CGFloat = 20) {
        self.size = size
    }

    public var body: some View {
        switch mascotChoice {
        case "disabled", "none", "off":
            EmptyView()
        case "cat":
            NotchCyberCatView(size: size)
        case "ghost":
            NotchCosmicGhostView(size: size)
        case "spark":
            NotchRetroSparkView(size: size)
        case "panda":
            NotchZenPandaView(size: size)
        default:
            PuffNotchView(size: size)
        }
    }
}

// MARK: - 1. Cyber Neko (Cat)

struct NotchCyberCatView: View {
    let size: CGFloat
    @State private var isBlinking = false
    @State private var earTwitch = false
    @State private var isHovered = false

    var body: some View {
        ZStack {
            // Cat ears
            HStack(spacing: size * 0.45) {
                Triangle()
                    .fill(Color(hex: 0x38BDF8))
                    .frame(width: size * 0.32, height: size * 0.35)
                    .rotationEffect(.degrees(earTwitch ? -18 : -8))
                Triangle()
                    .fill(Color(hex: 0x38BDF8))
                    .frame(width: size * 0.32, height: size * 0.35)
                    .rotationEffect(.degrees(earTwitch ? 18 : 8))
            }
            .offset(y: -size * 0.32)

            // Cat Head
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: 0x1E293B), Color(hex: 0x0F172A)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size * 0.9)
                .overlay(Circle().stroke(Color(hex: 0x38BDF8).opacity(0.8), lineWidth: 1.2))

            // Eyes
            HStack(spacing: size * 0.22) {
                if isBlinking {
                    Rectangle()
                        .fill(Color(hex: 0x34D399))
                        .frame(width: size * 0.18, height: 1.5)
                    Rectangle()
                        .fill(Color(hex: 0x34D399))
                        .frame(width: size * 0.18, height: 1.5)
                } else {
                    Circle()
                        .fill(Color(hex: 0x34D399))
                        .frame(width: size * 0.18, height: size * 0.18)
                        .shadow(color: Color(hex: 0x34D399).opacity(0.8), radius: 2)
                    Circle()
                        .fill(Color(hex: 0x34D399))
                        .frame(width: size * 0.18, height: size * 0.18)
                        .shadow(color: Color(hex: 0x34D399).opacity(0.8), radius: 2)
                }
            }
            .offset(y: -size * 0.04)

            // Nose & mouth
            VStack(spacing: 1) {
                Circle()
                    .fill(Color(hex: 0xF472B6))
                    .frame(width: size * 0.08, height: size * 0.08)
                Rectangle()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: 1, height: size * 0.06)
            }
            .offset(y: size * 0.16)
        }
        .frame(width: size, height: size)
        .scaleEffect(isHovered ? 1.15 : 1.0)
        .onHover { isHovered = $0 }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 3.2, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.12)) { isBlinking = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                    withAnimation(.easeInOut(duration: 0.12)) { isBlinking = false }
                }
            }
            Timer.scheduledTimer(withTimeInterval: 4.8, repeats: true) { _ in
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) { earTwitch.toggle() }
            }
        }
    }
}

// MARK: - 2. Cosmic Ghost

struct NotchCosmicGhostView: View {
    let size: CGFloat
    @State private var floatOffset: CGFloat = -1.2
    @State private var glowScale: CGFloat = 0.95

    var body: some View {
        ZStack {
            // Ethereal outer glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color(hex: 0x818CF8).opacity(0.55), Color.clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.8
                    )
                )
                .scaleEffect(glowScale)

            // Ghost Body
            VStack(spacing: 0) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white, Color(hex: 0xC7D2FE)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: size * 0.82, height: size * 0.7)

                HStack(spacing: 2) {
                    ForEach(0..<3) { i in
                        Circle()
                            .fill(Color(hex: 0xC7D2FE))
                            .frame(width: size * 0.24, height: size * 0.22)
                    }
                }
                .offset(y: -size * 0.08)
            }

            // Ghost Eyes
            HStack(spacing: size * 0.2) {
                Circle().fill(Color(hex: 0x312E81)).frame(width: size * 0.12, height: size * 0.16)
                Circle().fill(Color(hex: 0x312E81)).frame(width: size * 0.12, height: size * 0.16)
            }
            .offset(y: -size * 0.05)
        }
        .frame(width: size, height: size)
        .offset(y: floatOffset)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glowScale = 1.15
                floatOffset = 1.2
            }
        }
    }
}

// MARK: - 3. Retro Spark

struct NotchRetroSparkView: View {
    let size: CGFloat
    @State private var bounce = false
    @State private var sparkColor = Color(hex: 0xFACC15)

    var body: some View {
        ZStack {
            // Spark Star Polygon
            Image(systemName: "sparkles")
                .font(.system(size: size * 0.85, weight: .black))
                .foregroundColor(sparkColor)
                .shadow(color: sparkColor.opacity(0.8), radius: 4)
                .scaleEffect(bounce ? 1.12 : 0.92)
                .rotationEffect(.degrees(bounce ? 15 : -15))
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6).repeatForever(autoreverses: true)) {
                bounce = true
            }
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
                let colors = [Color(hex: 0xFACC15), Color(hex: 0x38BDF8), Color(hex: 0xF472B6), Color(hex: 0x4ADE80)]
                sparkColor = colors.randomElement() ?? Color(hex: 0xFACC15)
            }
        }
    }
}

// MARK: - 4. Zen Panda

struct NotchZenPandaView: View {
    let size: CGFloat
    @State private var isWinking = false

    var body: some View {
        ZStack {
            // Panda Ears
            HStack(spacing: size * 0.48) {
                Circle().fill(Color(hex: 0x111827)).frame(width: size * 0.32, height: size * 0.32)
                Circle().fill(Color(hex: 0x111827)).frame(width: size * 0.32, height: size * 0.32)
            }
            .offset(y: -size * 0.3)

            // Panda Face
            Circle()
                .fill(Color(hex: 0xF9FAFB))
                .frame(width: size * 0.92, height: size * 0.85)

            // Eye Patches
            HStack(spacing: size * 0.14) {
                Ellipse().fill(Color(hex: 0x1F2937)).frame(width: size * 0.28, height: size * 0.24)
                    .rotationEffect(.degrees(-15))
                Ellipse().fill(Color(hex: 0x1F2937)).frame(width: size * 0.28, height: size * 0.24)
                    .rotationEffect(.degrees(15))
            }
            .offset(y: -size * 0.05)

            // Eye Dots
            HStack(spacing: size * 0.24) {
                Circle().fill(Color.white).frame(width: size * 0.09, height: size * 0.09)
                if isWinking {
                    Rectangle().fill(Color.white).frame(width: size * 0.1, height: 1.5)
                } else {
                    Circle().fill(Color.white).frame(width: size * 0.09, height: size * 0.09)
                }
            }
            .offset(y: -size * 0.05)

            // Snout
            Ellipse()
                .fill(Color(hex: 0x111827))
                .frame(width: size * 0.14, height: size * 0.08)
                .offset(y: size * 0.12)
        }
        .frame(width: size, height: size)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 4.0, repeats: true) { _ in
                withAnimation(.easeInOut(duration: 0.15)) { isWinking = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                    withAnimation(.easeInOut(duration: 0.15)) { isWinking = false }
                }
            }
        }
    }
}

// Shape helper
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
