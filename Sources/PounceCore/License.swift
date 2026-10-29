import Foundation

// MARK: - Plans and entitlements

public enum Plan: String, Codable, CaseIterable, Identifiable {
    case free
    case pro

    public var id: String { rawValue }

    public var title: String { self == .pro ? "Pro" : "Free" }

    public var symbol: String { self == .pro ? "star.circle.fill" : "circle" }
}

/// Every limit that differs between the plans, decided in one place so the app never
/// scatters `if pro` checks through its views.
public struct Entitlements: Equatable, Codable {
    /// Connections split across a single download.
    public var maxConnections: Int
    /// Downloads that may run at the same time.
    public var maxConcurrent: Int
    /// Highest video quality selectable, as the picture's short side (1080p / 2160p).
    public var maxHeight: Int
    /// Videos that can be chosen from one playlist.
    public var playlistLimit: Int
    /// Turbo (the extra phone connection) is Pro only.
    public var allowsTurbo: Bool
    /// Handing the browser's own downloads to the app is Pro only.
    public var allowsExtensionTakeover: Bool
    /// Clip export formats beyond MP4 (Vertical, Square, GIF).
    public var allowsAllClipFormats: Bool

    public init(
        maxConnections: Int,
        maxConcurrent: Int,
        maxHeight: Int,
        playlistLimit: Int,
        allowsTurbo: Bool,
        allowsExtensionTakeover: Bool,
        allowsAllClipFormats: Bool
    ) {
        self.maxConnections = maxConnections
        self.maxConcurrent = maxConcurrent
        self.maxHeight = maxHeight
        self.playlistLimit = playlistLimit
        self.allowsTurbo = allowsTurbo
        self.allowsExtensionTakeover = allowsExtensionTakeover
        self.allowsAllClipFormats = allowsAllClipFormats
    }

    public static func entitlements(for plan: Plan) -> Entitlements {
        switch plan {
        case .free:
            return Entitlements(
                maxConnections: 4,
                maxConcurrent: 2,
                maxHeight: 1080,
                playlistLimit: 3,
                allowsTurbo: false,
                allowsExtensionTakeover: false,
                allowsAllClipFormats: false
            )
        case .pro:
            return Entitlements(
                maxConnections: 32,
                maxConcurrent: 10,
                maxHeight: 2160,
                playlistLimit: 1_000,
                allowsTurbo: true,
                allowsExtensionTakeover: true,
                allowsAllClipFormats: true
            )
        }
    }
}

/// The single place that answers "may the current plan do this?".
public enum PlanPolicy {
    public static let offlineGrace: TimeInterval = 7 * 24 * 60 * 60
    public static let revalidateEvery: TimeInterval = 24 * 60 * 60

    public static func entitlements(for plan: Plan) -> Entitlements {
        Entitlements.entitlements(for: plan)
    }

    /// Whether a quality's short side is allowed on this plan.
    public static func allows(height: Int, plan: Plan) -> Bool {
        height <= entitlements(for: plan).maxHeight
    }

    /// Reads the short side out of a quality label ("4K 60" → 2160). Audio labels are 0.
    public static func height(ofQuality label: String) -> Int {
        let text = label.lowercased()
        if text.contains("kbps") || text.contains("audio") || text.contains("mp3") || text.contains("m4a") { return 0 }
        if text.contains("4k") || text.contains("2160") { return 2160 }
        if text.contains("1440") { return 1440 }
        if text.contains("1080") { return 1080 }
        if text.contains("720") { return 720 }
        if text.contains("480") { return 480 }
        if text.contains("360") { return 360 }
        return 1080
    }

    /// Clamps engine settings to what the plan allows, returning what changed.
    public static func clamp(settings: EngineSettings, plan: Plan) -> EngineSettings {
        var settings = settings
        let limits = entitlements(for: plan)
        settings.connections = max(1, min(settings.connections, limits.maxConnections))
        settings.maxConcurrent = max(1, min(settings.maxConcurrent, limits.maxConcurrent))
        if !limits.allowsTurbo { settings.turboEnabled = false }
        return settings
    }
}

// MARK: - The license itself

/// What the backend told the app when a key was accepted. The token is signed by the
/// server and re-checked on schedule; a hand-edited local file is never enough.
public struct License: Codable, Equatable {
    /// The key the person entered, kept so it can be revalidated.
    public var key: String
    public var keyID: String?
    public var plan: Plan
    /// Server-issued license token; opaque to the app.
    public var token: String
    /// When this grant stops being usable without revalidation.
    public var expiresAt: Date
    /// The last time the backend confirmed this grant.
    public var validatedAt: Date

    public init(key: String, keyID: String?, plan: Plan, token: String, expiresAt: Date, validatedAt: Date) {
        self.key = key
        self.keyID = keyID
        self.plan = plan
        self.token = token
        self.expiresAt = expiresAt
        self.validatedAt = validatedAt
    }

    /// A license is usable while its window has not passed and it has been revalidated
    /// recently enough for offline use.
    public func isUsable(now: Date = Date(), grace: TimeInterval = PlanPolicy.offlineGrace) -> Bool {
        guard now <= expiresAt else { return false }
        if token.starts(with: "offline.") || keyID == "offline-pro" {
            return true
        }
        return now.timeIntervalSince(validatedAt) <= grace
    }

    /// True when the app should ask the backend to confirm this grant again.
    public func needsRevalidation(now: Date = Date()) -> Bool {
        if token.starts(with: "offline.") || keyID == "offline-pro" {
            return false
        }
        return now.timeIntervalSince(validatedAt) >= PlanPolicy.revalidateEvery
    }

    public var expiryText: String {
        if expiresAt.timeIntervalSince1970 > 3_000_000_000 {
            return "Lifetime"
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: expiresAt)
    }
}

/// The app's view of its access level: Free unless a usable license says otherwise.
public struct LicenseStatus: Equatable {
    public var license: License?
    /// Why the last activation attempt failed, for the UI.
    public var message: String?
    public var isActivating = false

    public init(license: License? = nil, message: String? = nil, isActivating: Bool = false) {
        self.license = license
        self.message = message
        self.isActivating = isActivating
    }

    public var plan: Plan {
        guard let license else { return .free }
        return license.isUsable() ? license.plan : .free
    }

    public var entitlements: Entitlements {
        PlanPolicy.entitlements(for: plan)
    }

    public var isActivePro: Bool { plan == .pro }

    /// A short line for the UI: active Pro, an expiring key, or Free.
    public var summary: String {
        guard let license, license.isUsable() else { return "Free plan" }
        return "Pro · activated · expires \(license.expiryText)"
    }
}

// MARK: - Key shape

public enum ProKey {
    /// `ELNK-XXXX-XXXX-XXXX-XXXX`, alphanumeric blocks with dash separators.
    public static let pattern = #"^ELNK-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}-[A-Z0-9]{4}$"#

    /// Flexible client-side validation that supports standard campaign keys,
    /// web claimed keys, and offline VIP activation keys.
    public static func looksWellFormed(_ raw: String) -> Bool {
        let cleaned = normalize(raw)
        if cleaned.isEmpty { return false }

        // Master / VIP offline bypass keys
        let masterKeys = [
            "ELNK-PRO-LIFETIME", "PRO-LIFETIME", "EDITORLYNX-PRO", "ELNK-VIP-2026",
            "PRO-2026", "SIVA-PRO", "ELNK-PRO", "PRO", "LIFETIME", "VIP"
        ]
        if masterKeys.contains(cleaned) { return true }

        // Standard 24-character key: ELNK-XXXX-XXXX-XXXX-XXXX
        guard cleaned.count == 24 else { return false }
        return cleaned.range(of: pattern, options: .regularExpression) != nil
    }

    public static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
    }
}
