import SwiftUI

struct ExpandedView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if let model = AppModel.shared, (model.detectedLink != nil || model.engine.activeCount > 0) {
                DownloadExpandedView()
            } else if let module = appState.activeModule {
                switch module {
                case .builtIn(.nowPlaying):
                    NowPlayingExpandedView()
                case .builtIn(.volumeHUD):
                    SystemHUDExpandedView()
                case .builtIn(.battery):
                    BatteryExpandedView()
                case .builtIn(.shelf):
                    ShelfExpandedView()
                case .builtIn(.connectivity):
                    ConnectivityExpandedView()
                case .builtIn(.notifications):
                    NotificationExpandedView()
                case .builtIn(.teleprompter):
                    TeleprompterExpandedView()
                case .builtIn(.downloads):
                    DownloadExpandedView()
                case .builtIn(.clipboard):
                    ClipboardExpandedView()
                case .builtIn(.quickNote):
                    QuickNoteView()
                case .extension_(let extensionID):
                    ExtensionRendererView(extensionID: extensionID, displayMode: .expanded)
                }
            } else if appState.nowPlayingEnabled && NowPlayingManager.shared.isPlaying {
                NowPlayingExpandedView()
            } else {
                HomeScreenView()
            }
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var horizontalPadding: CGFloat {
        appState.activeBuiltInModule == .nowPlaying ? 4 : 8
    }
}

struct ModuleSummaryItem: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
            Text(label)
                .font(.system(size: 9, weight: .medium))
        }
        .foregroundColor(.white.opacity(0.7))
    }
}
