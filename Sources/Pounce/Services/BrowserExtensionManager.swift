import Foundation
import AppKit
import SwiftUI

public struct BrowserItem: Identifiable {
    public var id: String
    public var name: String
    public var bundleID: String
    public var appPath: String
    public var iconSymbol: String
    public var extensionType: String // "chrome" or "firefox"
    public var defaultPathDisplay: String
    public var extensionsURL: String
    public var color: Color

    public var isInstalled: Bool {
        actualAppPath != nil
    }

    /// Resolves the installed application location on this Mac.
    public var actualAppPath: String? {
        if id == "zen" {
            if FileManager.default.fileExists(atPath: "/Applications/Zen Browser.app") { return "/Applications/Zen Browser.app" }
            if FileManager.default.fileExists(atPath: "/Applications/Zen.app") { return "/Applications/Zen.app" }
        }
        if id == "dia" {
            if FileManager.default.fileExists(atPath: "/Applications/Dia.app") { return "/Applications/Dia.app" }
            if FileManager.default.fileExists(atPath: "/Applications/Dia Browser.app") { return "/Applications/Dia Browser.app" }
        }
        if id == "arc" {
            if FileManager.default.fileExists(atPath: "/Applications/Arc.app") { return "/Applications/Arc.app" }
        }
        if FileManager.default.fileExists(atPath: appPath) { return appPath }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) { return url.path }
        let home = NSHomeDirectory()
        let userApp = "\(home)\(appPath)"
        if FileManager.default.fileExists(atPath: userApp) { return userApp }
        return nil
    }

    /// Resolves the real absolute extension folder path on this Mac.
    public var resolvedPath: String {
        let home = NSHomeDirectory()

        switch id {
        case "chrome":
            return "\(home)/Library/Application Support/Google/Chrome/Default/Extensions"

        case "brave":
            return "\(home)/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions"

        case "edge":
            return "\(home)/Library/Application Support/Microsoft Edge/Default/Extensions"

        case "arc":
            return "\(home)/Library/Application Support/Arc/User Data/Default/Extensions"

        case "dia":
            return "\(home)/Library/Application Support/Dia/User Data/Default/Extensions"

        case "firefox":
            let profilesDir = "\(home)/Library/Application Support/Firefox/Profiles"
            if let entries = try? FileManager.default.contentsOfDirectory(atPath: profilesDir) {
                if let defaultProfile = entries.first(where: { $0.contains(".default-release") || $0.contains(".default") }) {
                    return "\(profilesDir)/\(defaultProfile)/extensions"
                } else if let first = entries.first {
                    return "\(profilesDir)/\(first)/extensions"
                }
            }
            return "\(profilesDir)/[Profile_ID].default/extensions"

        case "zen":
            let candidates = [
                "\(home)/Library/Application Support/zen/Profiles",
                "\(home)/Library/Application Support/Zen/Profiles"
            ]
            for profilesDir in candidates {
                if let entries = try? FileManager.default.contentsOfDirectory(atPath: profilesDir) {
                    if let defaultProfile = entries.first(where: { $0.contains(".Default (release)") || $0.contains(".default") || $0.contains(".Default Profile") }) {
                        return "\(profilesDir)/\(defaultProfile)/extensions"
                    } else if let first = entries.first {
                        return "\(profilesDir)/\(first)/extensions"
                    }
                }
            }
            return "\(home)/Library/Application Support/zen/Profiles/[Profile_ID].default/extensions"

        case "safari":
            let safariExt = "\(home)/Library/Safari/Extensions"
            if FileManager.default.fileExists(atPath: safariExt) {
                return safariExt
            }
            return "/Applications"

        default:
            return defaultPathDisplay.replacingOccurrences(of: "~", with: home)
        }
    }
}

@MainActor
public final class BrowserExtensionManager {
    public static let shared = BrowserExtensionManager()

    public let browsers: [BrowserItem] = [
        BrowserItem(
            id: "chrome",
            name: "Google Chrome",
            bundleID: "com.google.Chrome",
            appPath: "/Applications/Google Chrome.app",
            iconSymbol: "globe",
            extensionType: "chrome",
            defaultPathDisplay: "~/Library/Application Support/Google/Chrome/Default/Extensions",
            extensionsURL: "chrome://extensions",
            color: Color(hex: 0x4285F4)
        ),
        BrowserItem(
            id: "zen",
            name: "Zen Browser",
            bundleID: "app.zen-browser.zen",
            appPath: "/Applications/Zen Browser.app",
            iconSymbol: "circle.hexagonpath.fill",
            extensionType: "firefox",
            defaultPathDisplay: "~/Library/Application Support/Zen/Profiles/[Profile_ID].default/extensions",
            extensionsURL: "about:debugging#/runtime/this-firefox",
            color: Color(hex: 0xA855F7)
        ),
        BrowserItem(
            id: "firefox",
            name: "Mozilla Firefox",
            bundleID: "org.mozilla.firefox",
            appPath: "/Applications/Firefox.app",
            iconSymbol: "flame.fill",
            extensionType: "firefox",
            defaultPathDisplay: "~/Library/Application Support/Firefox/Profiles/[Profile_ID].default/extensions",
            extensionsURL: "about:debugging#/runtime/this-firefox",
            color: Color(hex: 0xFF7139)
        ),
        BrowserItem(
            id: "brave",
            name: "Brave Browser",
            bundleID: "com.brave.Browser",
            appPath: "/Applications/Brave Browser.app",
            iconSymbol: "shield.fill",
            extensionType: "chrome",
            defaultPathDisplay: "~/Library/Application Support/BraveSoftware/Brave-Browser/Default/Extensions",
            extensionsURL: "brave://extensions",
            color: Color(hex: 0xFB542B)
        ),
        BrowserItem(
            id: "edge",
            name: "Microsoft Edge",
            bundleID: "com.microsoft.edgemac",
            appPath: "/Applications/Microsoft Edge.app",
            iconSymbol: "network",
            extensionType: "chrome",
            defaultPathDisplay: "~/Library/Application Support/Microsoft Edge/Default/Extensions",
            extensionsURL: "edge://extensions",
            color: Color(hex: 0x0078D7)
        ),
        BrowserItem(
            id: "arc",
            name: "Arc Browser",
            bundleID: "company.thebrowser.Browser",
            appPath: "/Applications/Arc.app",
            iconSymbol: "sparkles",
            extensionType: "chrome",
            defaultPathDisplay: "~/Library/Application Support/Arc/User Data/Default/Extensions",
            extensionsURL: "arc://extensions",
            color: Color(hex: 0x06B6D4)
        ),
        BrowserItem(
            id: "dia",
            name: "Dia",
            bundleID: "company.thebrowser.dia",
            appPath: "/Applications/Dia.app",
            iconSymbol: "diamond.fill",
            extensionType: "chrome",
            defaultPathDisplay: "~/Library/Application Support/Dia/User Data/Default/Extensions",
            extensionsURL: "chrome://extensions",
            color: Color(hex: 0x8B5CF6)
        ),
        BrowserItem(
            id: "safari",
            name: "Apple Safari",
            bundleID: "com.apple.Safari",
            appPath: "/Applications/Safari.app",
            iconSymbol: "safari.fill",
            extensionType: "chrome",
            defaultPathDisplay: "/Applications or ~/Library/Safari/Extensions",
            extensionsURL: "safari://extensions",
            color: Color(hex: 0x006CFF)
        )
    ]

    private init() {}

    /// Opens the extensions management tab in the target browser.
    public func openExtensionsPage(for browser: BrowserItem) {
        let pageURL = browser.extensionsURL

        if let appPath = browser.actualAppPath {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = ["-a", appPath, pageURL]
            do {
                try proc.run()
                return
            } catch {
                // Fallback to default opener
            }
        }

        if let url = URL(string: pageURL) {
            NSWorkspace.shared.open(url)
        }
    }

    /// Packs and downloads the extension into ~/Downloads, revealing it in Finder.
    public func downloadExtensionToDownloads(for browser: BrowserItem) -> URL? {
        let folderName = browser.extensionType // "chrome" or "firefox"
        let downloadsDir = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: "\(NSHomeDirectory())/Downloads")

        let bundled = Bundle.main.resourceURL?.appendingPathComponent("Extension/\(folderName)", isDirectory: true)
        let appBundleExt = URL(fileURLWithPath: "/Applications/Edit.or.lynx.app/Contents/Resources/Extension/\(folderName)", isDirectory: true)
        let project = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("Extension/\(folderName)", isDirectory: true)
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Edit.or.lynx/Extension/\(folderName)", isDirectory: true)

        guard let sourceURL = [bundled, appBundleExt, project, appSupport].compactMap({ $0 }).first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            return nil
        }

        let isFirefox = browser.extensionType == "firefox"
        let extName = browser.name.replacingOccurrences(of: " ", with: "")

        // 1. Create clean unpacked directory in ~/Downloads:
        let unpackedFolder = downloadsDir.appendingPathComponent("Edit.or.lynx-Extension-\(extName)", isDirectory: true)
        try? FileManager.default.removeItem(at: unpackedFolder)
        do {
            try FileManager.default.copyItem(at: sourceURL, to: unpackedFolder)
        } catch {
            // Ignore error if copy fails, will fallback to zip
        }

        // 2. Also build packaged zip archive in ~/Downloads:
        let destFileName = "Edit.or.lynx-Extension-\(extName).zip"
        let destURL = downloadsDir.appendingPathComponent(destFileName)
        try? FileManager.default.removeItem(at: destURL)

        let zipProcess = Process()
        zipProcess.currentDirectoryURL = sourceURL
        zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        zipProcess.arguments = ["-q", "-r", destURL.path, "."]
        do {
            try zipProcess.run()
            zipProcess.waitUntilExit()
        } catch {
            // zip creation failed, continue with unpackedFolder
        }

        // 3. Reveal in Finder:
        // For Zen/Firefox temporary add-on: reveal manifest.json so user can pick it in "Load Temporary Add-on..."
        let manifestFile = unpackedFolder.appendingPathComponent("manifest.json")
        let targetToReveal: URL
        if isFirefox && FileManager.default.fileExists(atPath: manifestFile.path) {
            targetToReveal = manifestFile
        } else if FileManager.default.fileExists(atPath: unpackedFolder.path) {
            targetToReveal = unpackedFolder
        } else {
            targetToReveal = destURL
        }

        if FileManager.default.fileExists(atPath: targetToReveal.path) {
            NSWorkspace.shared.activateFileViewerSelecting([targetToReveal])
            return targetToReveal
        }
        return nil
    }

    /// Convenience connector that opens extensions page and prepares extension.
    @discardableResult
    public func connectExtension(for browser: BrowserItem) -> (path: String, opened: Bool) {
        openExtensionsPage(for: browser)
        _ = downloadExtensionToDownloads(for: browser)
        return (browser.resolvedPath, true)
    }

    /// Copies the exact extension folder path of the given browser to the clipboard.
    public func copyExtensionPath(for browser: BrowserItem) -> String {
        let path = browser.resolvedPath
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
        return path
    }
}
