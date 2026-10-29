import Foundation

public enum Fmt {
    public static func bytes(_ value: Double) -> String {
        let units: [(String, Double)] = [("TB", 1_000_000_000_000), ("GB", 1_000_000_000), ("MB", 1_000_000), ("KB", 1_000)]
        let v = max(0, value)
        for (name, size) in units where v >= size {
            let n = v / size
            if abs(n - n.rounded()) < 0.05 {
                return String(format: "%.0f %@", n, name)
            } else if n >= 2 {
                return String(format: "%.1f %@", n, name)
            } else {
                return String(format: "%.2f %@", n, name)
            }
        }
        return String(format: "%.0f B", v)
    }

    public static func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 1 else { return "—" }
        let units: [(String, Double)] = [("GB", 1_000_000_000), ("MB", 1_000_000), ("KB", 1_000)]
        for (name, size) in units where bytesPerSecond >= size {
            return String(format: "%.1f %@/s", bytesPerSecond / size, name)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    public static func eta(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded()))
        if s < 60 { return "\(s) s left" }
        if s < 3_600 {
            let m = s / 60
            let rem = s % 60
            return rem > 10 ? "\(m) min \(rem) s left" : "\(m) min left"
        }
        let h = s / 3_600
        let m = (s % 3_600) / 60
        return "\(h) hr \(m) min left"
    }

    public static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        let h = total / 3_600
        let m = (total % 3_600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    public static func shortDuration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded()))
        if total < 60 { return "\(total) sec" }
        let m = total / 60
        let s = total % 60
        if s == 0 { return "\(m) min" }
        return "\(m) min \(s) sec"
    }

    public static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    public static func relative(_ date: Date, now: Date = Date()) -> String {
        let interval = max(0, now.timeIntervalSince(date))
        if interval < 45 { return "Just now" }
        if interval < 3_600 { return "\(Int(interval / 60)) min ago" }
        if interval < 86_400 { return "\(Int(interval / 3_600)) hr ago" }
        if interval < 172_800 { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    public static func timestamp(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        if calendar.isDateInToday(date) {
            return formatter.string(from: date)
        }
        if calendar.isDateInYesterday(date) {
            return "Yesterday"
        }
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }

    public static func dayHeader(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    public static func percent(_ progress: Double) -> String {
        "\(Int((min(1, max(0, progress)) * 100).rounded()))%"
    }
}
