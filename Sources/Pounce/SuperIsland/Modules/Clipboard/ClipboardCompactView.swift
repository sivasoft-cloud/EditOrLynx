import SwiftUI
import PounceCore

struct ClipboardCompactView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        HStack(spacing: 6) {
            if let model = AppModel.shared, let link = model.detectedLink {
                Image(systemName: "link.badge.plus")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Color(hex: 0x0A84FF))

                Text(link.title.isEmpty ? link.host : link.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
            } else if let model = AppModel.shared, let first = model.clipboard.first {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.85))

                Text(first.text)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                Text("Clipboard")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
}
