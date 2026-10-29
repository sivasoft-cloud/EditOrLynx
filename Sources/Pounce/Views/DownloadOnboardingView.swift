import SwiftUI
import AppKit
import Combine
import PounceCore

struct DownloadOnboardingView: View {
    @ObservedObject var model: AppModel
    var onComplete: () -> Void

    @State private var currentStep: Int = 0
    @State private var greetingIndex: Int = 0
    @State private var copiedNotice: String? = nil

    private let greetings: [(text: String, language: String)] = [
        ("hello", "English"),
        ("வணக்கம்", "Tamil"),
        ("bonjour", "French"),
        ("hola", "Spanish"),
        ("ciao", "Italian"),
        ("こんにちは", "Japanese"),
        ("नमस्ते", "Hindi"),
        ("olá", "Portuguese"),
        ("hallo", "German")
    ]

    private let greetingTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    init(model: AppModel, onComplete: @escaping () -> Void = {}) {
        self.model = model
        self.onComplete = onComplete
    }

    private var supportedBrowsers: [BrowserItem] {
        BrowserExtensionManager.shared.browsers
    }

    var body: some View {
        ZStack {
            // Ambient macOS Background with dynamic blurred layers
            backgroundLayer

            VStack(spacing: 0) {
                topHeader
                    .padding(.top, 22)
                    .padding(.horizontal, 28)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Group {
                            switch currentStep {
                            case 0:
                                macHelloStage
                            case 1:
                                welcomeStage
                            case 2:
                                browsersStage
                            default:
                                readyStage
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.98)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        ))
                        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: currentStep)
                    }
                    .frame(maxWidth: 820)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                bottomBar
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(
                        Pal.bg.opacity(0.85)
                            .overlay(alignment: .top) {
                                Rectangle().fill(Pal.stroke).frame(height: 0.7)
                            }
                    )
            }
        }
        .frame(minWidth: 700, idealWidth: 840, maxWidth: .infinity, minHeight: 520, idealHeight: 620, maxHeight: .infinity)
        .preferredColorScheme(.dark)
        .onReceive(greetingTimer) { _ in
            if currentStep == 0 {
                withAnimation(.easeInOut(duration: 0.6)) {
                    greetingIndex = (greetingIndex + 1) % greetings.count
                }
            }
        }
    }

    // MARK: - Ambient macOS Background Layer

    private var backgroundLayer: some View {
        ZStack {
            Pal.bg.ignoresSafeArea()

            // Dynamic Apple ambient mesh lighting
            RadialGradient(
                colors: [Pal.systemAccent.opacity(currentStep == 0 ? 0.18 : 0.12), .clear],
                center: .center,
                startRadius: 20,
                endRadius: 550
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.2), value: currentStep)

            RadialGradient(
                colors: [Pal.blue.opacity(0.10), .clear],
                center: .bottomLeading,
                startRadius: 30,
                endRadius: 480
            )
            .ignoresSafeArea()
        }
    }

    // MARK: - Top Header

    private var topHeader: some View {
        HStack {
            HStack(spacing: 10) {
                PounceMark(size: 26, glow: true)
                Text("Edit.or.lynx")
                    .font(Typo.display(14, .bold))
                    .foregroundStyle(Pal.text)

                if currentStep > 0 {
                    Text("MACOS INTRO")
                        .font(Typo.mono(8.5, .bold))
                        .foregroundStyle(Pal.systemAccent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Pal.systemAccent.opacity(0.14), in: Capsule())
                }
            }

            Spacer()

            // Step Indicator Dots (4 stages: hello, welcome, browsers, ready)
            HStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { idx in
                    Capsule()
                        .fill(idx == currentStep ? Pal.systemAccent : Color.white.opacity(0.2))
                        .frame(width: idx == currentStep ? 24 : 6, height: 6)
                        .animation(.spring(response: 0.3, dampingFraction: 0.78), value: currentStep)
                }
            }

            Button {
                onComplete()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Pal.tertiary)
            }
            .buttonStyle(.plain)
            .noFocusOutline()
            .padding(.leading, 12)
            .help("Skip Intro (esc)")
        }
    }

    // MARK: - Stage 0: macOS "hello" Animated Intro

    private var macHelloStage: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 20)

            // The Iconic macOS Cursive "hello"
            ZStack {
                // Soft breathing backlight glow
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Pal.systemAccent.opacity(0.25), Pal.blue.opacity(0.15)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 220, height: 220)
                    .blur(radius: 40)

                VStack(spacing: 6) {
                    Text(greetings[greetingIndex].text)
                        .font(.system(size: 72, weight: .light, design: .serif))
                        .italic()
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, Color.white.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .id(greetingIndex)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.94)),
                            removal: .opacity.combined(with: .scale(scale: 1.04))
                        ))

                    Text(greetings[greetingIndex].language)
                        .font(Typo.mono(10, .medium))
                        .tracking(1.2)
                        .foregroundStyle(Pal.tertiary)
                        .id("lang-\(greetingIndex)")
                        .transition(.opacity)
                }
            }
            .frame(height: 180)

            VStack(spacing: 8) {
                Text("Welcome to Edit.or.lynx")
                    .font(Typo.display(24, .bold))
                    .foregroundStyle(Pal.text)

                Text("A high-speed media download manager and companion engineered for macOS.")
                    .font(Typo.body(13))
                    .foregroundStyle(Pal.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 520)
            }

            Spacer(minLength: 20)
        }
    }

    // MARK: - Stage 1: Welcome & Features

    private var welcomeStage: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Pal.systemAccent.opacity(0.14))
                    .frame(width: 80, height: 80)
                    .blur(radius: 12)

                PounceMark(size: 64, glow: true)
            }
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text("Engineered for Apple Silicon")
                    .font(Typo.display(22, .bold))
                    .foregroundStyle(Pal.text)

                Text("The high-speed minimalist download manager embedded right inside your MacBook notch.")
                    .font(Typo.body(12))
                    .foregroundStyle(Pal.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 500)
            }

            // Feature Highlights Grid
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                featureTile(
                    symbol: "menubar.arrow.up.rectangle",
                    title: "Dynamic Notch HUD",
                    desc: "Live music visualizer, Spotify & Apple Music controls, and download progress ring.",
                    color: Pal.systemAccent
                )
                featureTile(
                    symbol: "bolt.fill",
                    title: "16x Multi-Thread Turbo",
                    desc: "Splits large downloads into 16 parallel segments to saturate gigabit connections.",
                    color: Pal.accent
                )
                featureTile(
                    symbol: "film.fill",
                    title: "4K & 8K HDR Downloader",
                    desc: "Universal MP4 conversion ensuring crystal-clear playback on QuickTime, iPhone & TV.",
                    color: Pal.green
                )
                featureTile(
                    symbol: "waveform",
                    title: "Studio Master & Lossless Audio",
                    desc: "320kbps & lossless bit-perfect streaming for Tamil, Indian, and international music.",
                    color: Color(red: 0.35, green: 0.65, blue: 1.0)
                )
            }
            .frame(maxWidth: 620)
            .padding(.top, 4)
        }
    }

    private func featureTile(symbol: String, title: String, desc: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.14))
                    .frame(width: 30, height: 30)
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Typo.body(11.5, .semibold))
                    .foregroundStyle(Pal.text)
                Text(desc)
                    .font(Typo.body(9.5))
                    .foregroundStyle(Pal.tertiary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(11)
        .background(Pal.recess.opacity(0.8), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Stage 2: Browser Extensions

    private var browsersStage: some View {
        VStack(spacing: 14) {
            VStack(spacing: 4) {
                Text("Connect Your Browsers")
                    .font(Typo.display(20, .bold))
                    .foregroundStyle(Pal.text)

                Text("1-Click connection for instant download interception directly to the notch.")
                    .font(Typo.body(11))
                    .foregroundStyle(Pal.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(supportedBrowsers) { browser in
                    browserCard(browser)
                }
            }
            .frame(maxWidth: 640)
        }
    }

    private func browserCard(_ browser: BrowserItem) -> some View {
        let installed = browser.isInstalled

        return HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(browser.color.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: browser.iconSymbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(browser.color)
            }

            VStack(alignment: .leading, spacing: 1.5) {
                HStack(spacing: 5) {
                    Text(browser.name)
                        .font(Typo.body(11.5, .semibold))
                        .foregroundStyle(Pal.text)
                    if installed {
                        Circle().fill(Pal.green).frame(width: 4, height: 4)
                    }
                }
                Text(browser.defaultPathDisplay)
                    .font(Typo.mono(8))
                    .foregroundStyle(Pal.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            HStack(spacing: 5) {
                Button {
                    BrowserExtensionManager.shared.openExtensionsPage(for: browser)
                    copiedNotice = "Opened \(browser.name) Extensions"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        if copiedNotice?.contains(browser.name) == true { copiedNotice = nil }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.system(size: 8))
                        Text("Open")
                            .font(Typo.body(9, .medium))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4.5)
                    .background(Pal.elevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.stroke, lineWidth: 0.6))
                }
                .buttonStyle(.plain)
                .noFocusOutline()

                Button {
                    if let _ = BrowserExtensionManager.shared.downloadExtensionToDownloads(for: browser) {
                        copiedNotice = "Saved to Downloads!"
                    } else {
                        copiedNotice = "Export failed"
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        copiedNotice = nil
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Download")
                            .font(Typo.body(9, .bold))
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4.5)
                    .background(Pal.systemAccent, in: Capsule())
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
        }
        .padding(10)
        .background(Pal.panel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(installed ? browser.color.opacity(0.35) : Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Stage 3: Ready

    private var readyStage: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Pal.green.opacity(0.14))
                    .frame(width: 76, height: 76)
                    .blur(radius: 12)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(Pal.green)
            }
            .padding(.top, 12)

            VStack(spacing: 4) {
                Text("You're All Set!")
                    .font(Typo.display(21, .bold))
                    .foregroundStyle(Pal.text)

                Text("Edit.or.lynx is running quietly in your MacBook notch.")
                    .font(Typo.body(12))
                    .foregroundStyle(Pal.secondary)
            }

            VStack(spacing: 9) {
                shortcutRow(key: "⌘ V", label: "Paste any link, video or media URL to download immediately.")
                shortcutRow(key: "Drag to Notch", label: "Drop images, clips, and files onto the notch to stage on Shelf.")
                shortcutRow(key: "Click Notch", label: "Open dynamic media HUD, Spotify & Apple Music controls.")
            }
            .frame(maxWidth: 540)
            .padding(.vertical, 6)
        }
    }

    private func shortcutRow(key: String, label: String) -> some View {
        HStack(spacing: 12) {
            Text(key)
                .font(Typo.mono(10.5, .bold))
                .foregroundStyle(Pal.systemAccent)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Pal.systemAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Pal.systemAccent.opacity(0.3), lineWidth: 0.8))
                .frame(width: 120, alignment: .trailing)

            Text(label)
                .font(Typo.body(11))
                .foregroundStyle(Pal.secondary)

            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Bottom Navigation Bar

    private var bottomBar: some View {
        HStack {
            if currentStep > 0 {
                Button {
                    withAnimation { currentStep -= 1 }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Back")
                            .font(Typo.body(11.5, .medium))
                    }
                    .foregroundStyle(Pal.secondary)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(Pal.elevated, in: Capsule())
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }

            Spacer()

            if currentStep < 3 {
                Button {
                    withAnimation { currentStep += 1 }
                } label: {
                    HStack(spacing: 6) {
                        Text(currentStep == 0 ? "Get Started" : (currentStep == 1 ? "Connect Browsers" : "Next"))
                            .font(Typo.body(12, .semibold))
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 18)
                    .frame(height: 34)
                    .background(Pal.systemAccent, in: Capsule())
                    .shadow(color: Pal.systemAccent.opacity(0.3), radius: 6, y: 2)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            } else {
                Button {
                    onComplete()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Enter Edit.or.lynx")
                            .font(Typo.body(12, .bold))
                    }
                    .foregroundStyle(Color.black.opacity(0.9))
                    .padding(.horizontal, 22)
                    .frame(height: 34)
                    .background(Pal.green, in: Capsule())
                    .shadow(color: Pal.green.opacity(0.4), radius: 8, y: 2)
                }
                .buttonStyle(.plain)
                .noFocusOutline()
            }
        }
    }
}

typealias MacOSWelcomeIntroView = DownloadOnboardingView
