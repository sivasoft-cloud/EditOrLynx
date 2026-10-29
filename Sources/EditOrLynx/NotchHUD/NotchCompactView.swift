import SwiftUI

public struct NotchCompactView: View {
    @EnvironmentObject var engine: DownloadEngine

    public var body: some View {
        HStack(spacing: 8) {
            let active = engine.activeDownloads.values.filter { $0.state.isActive }

            if let top = active.first {
                // Active download compact view
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.accentColor)

                    Text(Formatters.speed(top.speed))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)

                    ProgressView(value: top.progress)
                        .progressViewStyle(.linear)
                        .frame(width: 40)
                }
            } else {
                // Sleek Idle Brand View
                HStack(spacing: 6) {
                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color.accentColor)

                    Text("Edit.or.lynx")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                }
            }
        }
        .padding(.horizontal, 10)
    }
}
