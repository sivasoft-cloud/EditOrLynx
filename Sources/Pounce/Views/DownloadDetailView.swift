import SwiftUI
import Charts
import PounceCore

struct ChartSamplePoint: Identifiable {
    var id: Int
    var speed: Double
}

@available(macOS 13.0, *)
struct SwiftChartsSpeedProfile: View {
    let chartPoints: [ChartSamplePoint]
    let chartProgress: Double

    var body: some View {
        Chart {
            ForEach(chartPoints) { pt in
                AreaMark(
                    x: .value("Sample", pt.id),
                    y: .value("Speed", pt.speed)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Pal.systemAccent.opacity(0.24),
                            Pal.systemAccent.opacity(0.01)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Sample", pt.id),
                    y: .value("Speed", pt.speed)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Pal.systemAccent.opacity(0.85))
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .frame(height: 52)
        .padding(.horizontal, 4)
        .mask(
            GeometryReader { geo in
                Rectangle()
                    .frame(width: geo.size.width * chartProgress)
            }
        )
    }
}

struct DownloadDetailView: View {
    let item: DownloadItem
    @ObservedObject var model: AppModel

    @State private var chartProgress: Double = 0.0
    @State private var hoveredButton: String? = nil

    private var chartPoints: [ChartSamplePoint] {
        let values: [Double]
        if item.speedSamples.count >= 2 {
            values = item.speedSamples
        } else {
            let base = max(1.0, item.currentSpeed / 1_048_576.0)
            values = [base * 0.35, base * 0.65, base * 0.9, base * 0.82, base * 1.0]
        }
        return values.enumerated().map { index, val in
            ChartSamplePoint(id: index, speed: max(0.05, val))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    prominentThumbnail
                    titleSection
                    progressSection
                    speedProfileSection
                    metadataSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .compatScrollIndicatorsHidden()

            bottomActionSection
        }
        .frame(width: 330)
        .background(.ultraThinMaterial)
        .overlay(alignment: .leading) {
            Rectangle().fill(Pal.stroke).frame(width: 1)
        }
        .onAppear {
            chartProgress = 0
            withAnimation(.easeInOut(duration: 0.85)) {
                chartProgress = 1.0
            }
        }
        .id(item.id)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("DOWNLOAD DETAILS")
                .font(Typo.body(9.5, .bold))
                .tracking(1.2)
                .foregroundStyle(Pal.tertiary)

            Spacer()

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    model.selectedDownloadID = nil
                }
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Pal.secondary)
                    .frame(width: 24, height: 24)
                    .background(Pal.veil(0.06), in: Circle())
            }
            .buttonStyle(.plain)
            .scaleEffect(hoveredButton == "close" ? 1.05 : 1.0)
            .onHover { hoveredButton = $0 ? "close" : nil }
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 12)
    }

    // MARK: - Prominent Thumbnail

    private var prominentThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            // Glassmorphic preview canvas
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Pal.recess)
                .overlay(
                    LinearGradient(
                        colors: [Color.white.opacity(0.06), Color.clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Dynamic background texture
            Image(systemName: item.kind.symbol)
                .font(.system(size: 44, weight: .ultraLight))
                .foregroundStyle(Color.white.opacity(0.12))
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Top-right status pill
            VStack {
                HStack {
                    Spacer()
                    HStack(spacing: 4.5) {
                        Circle()
                            .fill(item.state == .completed ? Color(red: 0.22, green: 0.76, blue: 0.44) : Pal.systemAccent)
                            .frame(width: 5, height: 5)
                        Text(item.state.label.uppercased())
                            .font(Typo.body(8, .bold))
                            .tracking(0.6)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 0.8))
                    .padding(10)
                }
                Spacer()
            }

            // Bottom metadata badges
            HStack(spacing: 6) {
                badgeChip(text: item.formatLabel.uppercased())
                if item.qualityLabel != "—" {
                    badgeChip(text: item.qualityLabel.uppercased())
                }
                Spacer()
                badgeChip(text: item.sizeText.uppercased())
            }
            .padding(12)
        }
        .frame(height: 156)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 10, y: 4)
    }

    private func badgeChip(text: String) -> some View {
        Text(text)
            .font(Typo.mono(8.5, .bold))
            .foregroundStyle(Color.white.opacity(0.9))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(Color.black.opacity(0.55), in: Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.6))
    }

    // MARK: - Title Section

    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.title)
                .font(Typo.display(15, .bold))
                .foregroundStyle(Pal.text)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)

            Text(item.detailLine)
                .font(Typo.body(11))
                .foregroundStyle(Pal.secondary)
                .lineLimit(1)
        }
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .lastTextBaseline) {
                Text(item.statusHint != nil ? "100%" : (item.percentText ?? (item.downloadedBytes > 0 ? Fmt.bytes(Double(item.downloadedBytes)) : "0%")))
                    .font(Typo.mono(24, .bold))
                    .foregroundStyle(item.state == .completed ? Color(red: 0.22, green: 0.76, blue: 0.44) : Pal.text)

                Spacer()

                Text(item.statusHint ?? (item.state == .downloading ? Fmt.speed(item.currentSpeed) : item.state.label))
                    .font(Typo.mono(11, .semibold))
                    .foregroundStyle(item.state == .downloading ? Pal.systemAccent : Pal.secondary)
            }

            ProgressView(value: item.statusHint != nil ? 1.0 : (item.state == .completed ? 1.0 : item.progress))
                .progressViewStyle(.linear)
                .tint(item.state == .completed ? Color(red: 0.22, green: 0.76, blue: 0.44) : Pal.systemAccent)
        }
        .padding(12)
        .background(Pal.recess.opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Swift Charts Speed Profile Section

    private var speedProfileSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Text("SPEED PROFILE")
                        .font(Typo.body(9, .bold))
                        .tracking(1.0)
                        .foregroundStyle(Pal.tertiary)

                    if item.state == .downloading {
                        if #available(macOS 14.0, *) {
                            Circle()
                                .fill(Color(red: 0.22, green: 0.76, blue: 0.44))
                                .frame(width: 6, height: 6)
                                .phaseAnimator([0.35, 1.0, 0.35]) { view, phase in
                                    view
                                        .opacity(phase)
                                        .scaleEffect(phase > 0.7 ? 1.3 : 1.0)
                                }
                        } else {
                            Circle()
                                .fill(Color(red: 0.22, green: 0.76, blue: 0.44))
                                .frame(width: 6, height: 6)
                        }
                    }
                }

                Spacer()

                Text(item.isTurbo ? "Turbo 16x" : "Direct network")
                    .font(Typo.mono(9, .medium))
                    .foregroundStyle(item.isTurbo ? Pal.systemAccent : Pal.tertiary)
            }

            if #available(macOS 13.0, *) {
                SwiftChartsSpeedProfile(chartPoints: chartPoints, chartProgress: chartProgress)
            } else {
                Sparkline(samples: item.speedSamples, tint: Pal.systemAccent)
                    .frame(height: 52)
            }
        }
        .padding(12)
        .background(Pal.recess.opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(spacing: 0) {
            metaRow(title: "Format", value: item.formatLabel.uppercased())
            metaDivider
            metaRow(title: "Quality", value: item.qualityLabel == "—" ? item.kind.displayName : item.qualityLabel)
            metaDivider
            metaRow(title: "File Size", value: item.hasKnownSize ? item.sizeText : "Streaming")
            metaDivider
            metaRow(title: "Source Host", value: item.sourceHost)
            metaDivider
            metaRow(title: "Connections", value: "\(item.connectionCount) streams")
            metaDivider
            metaRow(title: "Saved To", value: item.savingToDisplay, truncate: true)
        }
        .padding(.horizontal, 12)
        .background(Pal.recess.opacity(0.6), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.stroke, lineWidth: 0.8)
        )
    }

    private func metaRow(title: String, value: String, truncate: Bool = false) -> some View {
        HStack {
            Text(title)
                .font(Typo.body(10))
                .foregroundStyle(Pal.tertiary)
            Spacer()
            Text(value)
                .font(Typo.body(10, .medium))
                .foregroundStyle(Pal.secondary)
                .lineLimit(1)
                .truncationMode(truncate ? .middle : .tail)
        }
        .padding(.vertical, 7)
    }

    private var metaDivider: some View {
        Rectangle().fill(Pal.stroke).frame(height: 0.7)
    }

    // MARK: - Bottom Actions Section

    private var bottomActionSection: some View {
        VStack(spacing: 8) {
            // Large Full-Width Button: Open File
            fullWidthActionButton(
                title: "Open File",
                symbol: "arrow.up.forward.app",
                isPrimary: true
            ) {
                model.openFile(for: item)
            }

            // Large Full-Width Button: Show in Finder
            fullWidthActionButton(
                title: "Show in Finder",
                symbol: "folder",
                isPrimary: false
            ) {
                model.revealDestination(for: item)
            }

            // Final Bottom Row: Copy Link and Remove
            HStack(spacing: 8) {
                halfWidthActionButton(
                    title: "Copy Link",
                    symbol: "link"
                ) {
                    model.copySourceLink(item)
                }

                halfWidthActionButton(
                    title: "Remove",
                    symbol: "trash",
                    isDestructive: true
                ) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        model.remove(item)
                    }
                }
            }
        }
        .padding(18)
        .background(.thinMaterial)
        .overlay(alignment: .top) {
            Rectangle().fill(Pal.stroke).frame(height: 0.8)
        }
    }

    private func fullWidthActionButton(title: String, symbol: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredButton == title

        return Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(Typo.body(12, .semibold))
            }
            .foregroundStyle(isPrimary ? Pal.onAccent : Pal.text)
            .frame(maxWidth: .infinity)
            .frame(height: 34)
            .background(
                isPrimary ? Pal.systemAccent : Pal.elevated,
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(isPrimary ? Color.clear : Pal.strokeStrong, lineWidth: 0.8)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hoveredButton = $0 ? title : nil }
    }

    private func halfWidthActionButton(title: String, symbol: String, isDestructive: Bool = false, action: @escaping () -> Void) -> some View {
        let isHovered = hoveredButton == title

        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                Text(title)
                    .font(Typo.body(11, .medium))
            }
            .foregroundStyle(isDestructive ? Pal.red : Pal.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 30)
            .background(Pal.elevated, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Pal.stroke, lineWidth: 0.8)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hoveredButton = $0 ? title : nil }
    }
}
