import SwiftUI

public struct AddDownloadSheet: View {
    @EnvironmentObject var engine: DownloadEngine
    @Binding public var isPresented: Bool

    @State private var urlString: String = ""
    @State private var connections: Int = 16
    @State private var detectedType: LinkType?

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Add New Download")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(AppTheme.textTertiary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("DOWNLOAD URL OR MAGNET LINK")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppTheme.textTertiary)

                TextField("https://... or magnet:?xt=...", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: urlString) { _, newVal in
                        detectedType = LinkClassifier.classify(newVal)
                    }
            }

            HStack {
                Text("Parallel Connections")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textSecondary)
                Spacer()
                Picker("", selection: $connections) {
                    Text("4 threads").tag(4)
                    Text("8 threads").tag(8)
                    Text("16 threads").tag(16)
                    Text("32 threads (Turbo)").tag(32)
                }
                .frame(width: 150)
            }

            HStack {
                Spacer()
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Button("Start Turbo Download") {
                    guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)) else { return }
                    _ = engine.startDownload(url: url, connections: connections)
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 440)
        .background(AppTheme.bg)
        .onAppear {
            if let paste = NSPasteboard.general.string(forType: .string),
               let u = URL(string: paste.trimmingCharacters(in: .whitespacesAndNewlines)),
               u.scheme == "http" || u.scheme == "https" || u.scheme == "magnet" {
                urlString = paste
                detectedType = LinkClassifier.classify(paste)
            }
        }
    }
}
