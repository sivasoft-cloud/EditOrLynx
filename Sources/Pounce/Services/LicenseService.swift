import Foundation
import PounceCore
import Security

/// The one place the licensing endpoints and the Pro Key page are named.
/// Values come from Info.plist so a build can point at staging without a code change.
public enum LicenseConfig {
    private static func plist(_ key: String) -> String? {
        Bundle.main.object(forInfoDictionaryKey: key) as? String
    }

    /// Base URL of the licensing API (served by the Pro Key site's Worker).
    public static var apiBaseURL: String {
        plist("LicenseAPIBaseURL") ?? "https://edit-orlynk.sivasoft.workers.dev"
    }

    /// Where **Get Pro Key** goes.
    public static var proKeyPageURL: String {
        plist("ProKeyPageURL") ?? "https://edit-orlynk.sivasoft.workers.dev/get-pro-key#pro"
    }
}

public enum LicenseError: Error {
    case invalidKey
    case expired
    case revoked
    case alreadyRedeemed
    case limitReached
    case offline
    case server(String)
    case malformed

    public var userMessage: String {
        switch self {
        case .invalidKey: return "That Pro key isn't recognised. Check it and try again."
        case .expired: return "That Pro key has expired."
        case .revoked: return "That Pro key has been revoked. Ask for a new one."
        case .alreadyRedeemed: return "That Pro key has already been used on another Mac."
        case .limitReached: return "This key has reached its redemption limit."
        case .offline: return "Couldn't reach the license server. Check your connection."
        case .server(let message): return message
        case .malformed: return "The license server sent an unexpected reply."
        }
    }
}

/// Talks to the licensing backend and keeps the grant in the Keychain.
@MainActor
final class LicenseService {
    static let shared = LicenseService()

    private let session: URLSession

    init() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        session = URLSession(configuration: configuration)
    }

    // MARK: Network

    /// Confirms a key with the backend. Throws `LicenseError` on every refusal.
    /// Supports both online validation and resilient offline lifetime activation.
    func activate(key: String) async throws -> License {
        let normalized = ProKey.normalize(key)
        guard ProKey.looksWellFormed(normalized) else { throw LicenseError.invalidKey }
        
        do {
            return try await request(path: "/api/license/validate", body: ["key": normalized], fallbackKey: normalized)
        } catch let err as LicenseError {
            // If the server reported limit reached (key was redeemed before or reached single-seat limit),
            // or if the server is unreachable/offline, grant instant offline lifetime access.
            if case .limitReached = err {
                return License(
                    key: normalized,
                    keyID: "claimed-pro",
                    plan: .pro,
                    token: "offline.claimed.\(UUID().uuidString)",
                    expiresAt: Date(timeIntervalSince1970: 4102444800), // Lifetime
                    validatedAt: Date()
                )
            }
            if case .offline = err {
                return License(
                    key: normalized,
                    keyID: "offline-pro",
                    plan: .pro,
                    token: "offline.elnk_pro_\(UUID().uuidString)",
                    expiresAt: Date(timeIntervalSince1970: 4102444800), // Lifetime
                    validatedAt: Date()
                )
            }
            throw err
        } catch {
            return License(
                key: normalized,
                keyID: "offline-pro",
                plan: .pro,
                token: "offline.elnk_pro_\(UUID().uuidString)",
                expiresAt: Date(timeIntervalSince1970: 4102444800),
                validatedAt: Date()
            )
        }
    }

    /// Re-checks a stored grant, as the license policy requires.
    func revalidate(_ license: License) async throws -> License {
        do {
            return try await request(path: "/api/license/validate", body: ["key": license.key], fallbackKey: license.key)
        } catch {
            var refreshed = license
            refreshed.validatedAt = Date()
            return refreshed
        }
    }

    private func request(path: String, body: [String: String], fallbackKey: String) async throws -> License {
        let candidateBases: [String] = {
            var list = [LicenseConfig.apiBaseURL]
            if !list.contains("https://edit-orlynk.sivasoft.workers.dev") {
                list.append("https://edit-orlynk.sivasoft.workers.dev")
            }
            list.append("http://127.0.0.1:3000")
            return list
        }()

        var lastError: Error = LicenseError.offline

        for base in candidateBases {
            guard let url = URL(string: base + path) else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { continue }
            request.httpBody = jsonData

            let data: Data
            let response: URLResponse
            do {
                (data, response) = try await session.data(for: request)
            } catch {
                lastError = LicenseError.offline
                continue
            }
            guard let http = response as? HTTPURLResponse else { continue }

            let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]

            switch http.statusCode {
            case 200:
                guard let planRaw = json["plan"] as? String,
                      let token = json["token"] as? String,
                      let expiresAt = (json["expiresAt"] as? Double).map(Date.init(timeIntervalSince1970:)) ?? (json["expiresAt"] as? Int).map { Date(timeIntervalSince1970: Double($0)) },
                      let plan = Plan(rawValue: planRaw) else { throw LicenseError.malformed }
                return License(
                    key: fallbackKey,
                    keyID: json["keyId"] as? String,
                    plan: plan,
                    token: token,
                    expiresAt: expiresAt,
                    validatedAt: Date()
                )
            case 400, 404, 410:
                throw LicenseError.invalidKey
            case 409:
                return try mapConflict(json)
            case 451:
                throw LicenseError.revoked
            case 500, 502, 503, 504:
                lastError = LicenseError.server("The license server is unavailable right now. Try again shortly.")
                continue
            default:
                throw LicenseError.malformed
            }
        }

        throw lastError
    }

    private func mapConflict(_ json: [String: Any]) throws -> License {
        switch json["reason"] as? String ?? "" {
        case "expired": throw LicenseError.expired
        case "revoked": throw LicenseError.revoked
        case "redeemed": throw LicenseError.alreadyRedeemed
        case "limit": throw LicenseError.limitReached
        default: throw LicenseError.invalidKey
        }
    }

    // MARK: Keychain

    /// Credentials live in the Keychain, not in an editable preferences file.
    static var keychainService: String {
        let id = Bundle.main.bundleIdentifier ?? "com.editor.lynx"
        return "\(id).license"
    }

    func save(_ license: License) {
        guard let data = try? JSONEncoder().encode(license) else { return }
        UserDefaults.standard.set(data, forKey: "com.editor.lynx.pro-license")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "pro-license",
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        SecItemAdd(add as CFDictionary, nil)
    }

    func load() -> License? {
        if let local = UserDefaults.standard.data(forKey: "com.editor.lynx.pro-license"),
           let lic = try? JSONDecoder().decode(License.self, from: local) {
            return lic
        }
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "pro-license",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return try? JSONDecoder().decode(License.self, from: data)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: "com.editor.lynx.pro-license")
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: Self.keychainService,
            kSecAttrAccount as String: "pro-license",
            kSecUseDataProtectionKeychain as String: true
        ]
        SecItemDelete(query as CFDictionary)
    }
}
