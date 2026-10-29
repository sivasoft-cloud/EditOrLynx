import SwiftUI
import PounceCore

/// Shown only after a real file has been written to disk: an animated green tick, the
/// message, the file's name and final size, and a way to open or repeat it.
struct CompletionOverlay: View {
    @ObservedObject var model: AppModel
    let item: DownloadItem
    @State private var drawn = false

    private var fileURL: URL? {
        item.fileURL.flatMap { FileManager.default.fileExists(atPath: $0.path) ? $0 : nil }
    }

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Pal.green.opacity(0.12))
                    .frame(width: 72, height: 72)
                Circle()
                    .strokeBorder(Pal.green.opacity(0.45), lineWidth: 1.5)
                    .frame(width: 72, height: 72)
                Circle()
                    .fill(Pal.green.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .blur(radius: 12)

                Image(systemName: "checkmark")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(Pal.green)
                    .scaleEffect(drawn ? 1 : 0.2)
                    .opacity(drawn ? 1 : 0)
            }
            .shadow(color: Pal.green.opacity(0.35), radius: 10)

            VStack(spacing: 6) {
                Text("Download Completed!")
                    .font(Typo.display(16.5, .bold))
                    .foregroundStyle(Pal.text)

                Text(fileName)
                    .font(Typo.mono(11.5, .semibold))
                    .foregroundStyle(Pal.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(finalSize)
                    .font(Typo.body(10, .medium))
                    .foregroundStyle(Pal.tertiary)
            }

            HStack(spacing: 10) {
                Button {
                    model.openFile(for: item)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10.5, weight: .bold))
                        Text("Open File")
                            .font(Typo.body(11.5, .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.88))
                    .padding(.horizontal, 15)
                    .frame(height: 32)
                    .background(
                        LinearGradient(colors: [Pal.green, Color(hex: 0x22C55E)], startPoint: .top, endPoint: .bottom),
                        in: Capsule()
                    )
                    .shadow(color: Pal.green.opacity(0.35), radius: 6, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    model.downloadAgain(item)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 10, weight: .bold))
                        Text("Download Again")
                            .font(Typo.body(11.5, .medium))
                    }
                    .foregroundStyle(Pal.text)
                    .padding(.horizontal, 14)
                    .frame(height: 32)
                    .background(Pal.elevated, in: Capsule())
                    .overlay(Capsule().strokeBorder(Pal.strokeStrong, lineWidth: 0.8))
                }
                .buttonStyle(.plain)

                Button {
                    model.dismissCompletedNotice()
                } label: {
                    Text("Dismiss")
                        .font(Typo.body(11, .medium))
                        .foregroundStyle(Pal.tertiary)
                        .padding(.horizontal, 10)
                        .frame(height: 32)
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.vertical, 26)
        .padding(.horizontal, 28)
        .frame(width: 440)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Pal.panel.opacity(0.95))
                .shadow(color: .black.opacity(0.4), radius: 30, y: 14)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Pal.green.opacity(0.25), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72).delay(0.06)) { drawn = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
                withAnimation(.easeOut(duration: 0.25)) {
                    model.dismissCompletedNotice()
                }
            }
        }
        .onDisappear { drawn = false }
        .accessibilityLabel("Download completed successfully")
    }

    private var fileName: String {
        item.filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? item.title
    }

    private var finalSize: String {
        Fmt.bytes(Double(item.totalBytes))
    }
}

/// The same success facts, kept in the detail pane for items that finished earlier.
struct SuccessSummary: View {
    @ObservedObject var model: AppModel
    let item: DownloadItem

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Pal.green)
                Text("Saved to Disk")
                    .font(Typo.body(11.5, .bold))
                    .foregroundStyle(Pal.text)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(fileName)
                    .font(Typo.mono(10, .medium))
                    .foregroundStyle(Pal.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(Fmt.bytes(Double(item.totalBytes)))
                    .font(Typo.body(9.5))
                    .foregroundStyle(Pal.tertiary)
            }

            HStack(spacing: 8) {
                SoftButton(title: "Open File", symbol: "doc.text.fill", accent: true) {
                    model.openFile(for: item)
                }
                SoftButton(title: "Download Again", symbol: "arrow.clockwise") {
                    model.downloadAgain(item)
                }
            }
        }
        .padding(12)
        .background(Pal.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(Pal.green.opacity(0.26), lineWidth: 0.8)
        )
    }

    private var fileName: String {
        item.filePath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? item.title
    }
}
