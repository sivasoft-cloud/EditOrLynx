import AppKit
import Combine

@MainActor
public final class ClipboardMonitor: ObservableObject {
    public static let shared = ClipboardMonitor()

    @Published public var detectedURL: URL?
    @Published public var isMonitoring: Bool = true

    private var lastChangeCount: Int = 0
    private var timer: AnyCancellable?

    private init() {
        lastChangeCount = NSPasteboard.general.changeCount
        startMonitoring()
    }

    public func startMonitoring() {
        isMonitoring = true
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkPasteboard()
            }
    }

    public func stopMonitoring() {
        isMonitoring = false
        timer?.cancel()
        timer = nil
    }

    private func checkPasteboard() {
        let currentCount = NSPasteboard.general.changeCount
        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let str = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: str),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" || scheme == "magnet" else {
            return
        }

        detectedURL = url
    }
}
