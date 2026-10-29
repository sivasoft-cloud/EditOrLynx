import Foundation

public enum Formatters {
    private static let byteCountFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowedUnits = [.useAll]
        f.allowsNonnumericFormatting = false
        return f
    }()

    public static func bytes(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 B" }
        return byteCountFormatter.string(fromByteCount: bytes)
    }

    public static func speed(_ bytesPerSec: Double) -> String {
        guard bytesPerSec > 0 else { return "0 B/s" }
        if bytesPerSec >= 1024 * 1024 * 1024 {
            return String(format: "%.2f GB/s", bytesPerSec / (1024 * 1024 * 1024))
        } else if bytesPerSec >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSec / (1024 * 1024))
        } else if bytesPerSec >= 1024 {
            return String(format: "%.0f KB/s", bytesPerSec / 1024)
        } else {
            return String(format: "%.0f B/s", bytesPerSec)
        }
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite && seconds > 0 else { return "--:--" }
        let total = Int(seconds)
        let s = total % 60
        let m = (total / 60) % 60
        let h = total / 3600

        if h > 0 {
            return String(format: "%dh %02dm", h, m)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    public static func eta(_ seconds: TimeInterval?) -> String {
        guard let s = seconds, s.isFinite, s > 0 else { return "Calculating…" }
        return duration(s)
    }
}
