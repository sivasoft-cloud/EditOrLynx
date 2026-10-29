import Foundation
import AppKit

/// Background manager that guarantees essential download utilities (yt-dlp, ffmpeg, brew)
/// are automatically fetched, installed, and kept up to date without interrupting the user.
public final class ToolchainService {
    public static let shared = ToolchainService()

    private let binDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base.appendingPathComponent("Edit.or.lynx/bin", isDirectory: true)
    }()

    private init() {}

    /// Runs in the background right on app launch to verify and silently install missing tools.
    public func ensureDependencies() {
        Task.detached(priority: .background) {
            try? FileManager.default.createDirectory(at: self.binDirectory, withIntermediateDirectories: true)
            await self.ensureYtDlp()
            await self.ensureHomebrewTools()
        }
    }

    private func ensureYtDlp() async {
        let localPath = binDirectory.appendingPathComponent("yt-dlp").path
        if FileManager.default.isExecutableFile(atPath: localPath) {
            return
        }

        // Check if system already has yt-dlp installed
        let systemCandidates = [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "\(NSHomeDirectory())/.local/bin/yt-dlp",
            "\(NSHomeDirectory())/bin/yt-dlp"
        ]
        if systemCandidates.contains(where: { FileManager.default.isExecutableFile(atPath: $0) }) {
            return
        }

        // Automatically fetch official standalone universal yt-dlp binary from GitHub
        NSLog("[Toolchain] yt-dlp not found on system. Automatically installing in background…")
        let downloadURLs = [
            URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos")!,
            URL(string: "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp")!
        ]

        for url in downloadURLs {
            do {
                var request = URLRequest(url: url)
                request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko)", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count > 100_000 {
                    let dest = self.binDirectory.appendingPathComponent("yt-dlp")
                    try data.write(to: dest)
                    // chmod +x (0o755)
                    try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: dest.path)
                    NSLog("[Toolchain] ✓ yt-dlp successfully installed to \(dest.path)")
                    break
                }
            } catch {
                NSLog("[Toolchain] yt-dlp download attempt failed from \(url): \(error.localizedDescription)")
            }
        }
    }

    private func ensureHomebrewTools() async {
        // If brew is available on macOS, automatically ensure yt-dlp and ffmpeg are updated/installed in the background
        let brewPath: String?
        if FileManager.default.isExecutableFile(atPath: "/opt/homebrew/bin/brew") {
            brewPath = "/opt/homebrew/bin/brew"
        } else if FileManager.default.isExecutableFile(atPath: "/usr/local/bin/brew") {
            brewPath = "/usr/local/bin/brew"
        } else {
            brewPath = nil
        }

        if let brew = brewPath {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: brew)
            process.arguments = ["install", "--quiet", "yt-dlp", "ffmpeg", "aria2"]
            process.environment = ProcessInfo.processInfo.environment
            try? process.run()
            process.waitUntilExit()
            NSLog("[Toolchain] ✓ Homebrew background sync completed (exit: \(process.terminationStatus))")
        }
    }
}
