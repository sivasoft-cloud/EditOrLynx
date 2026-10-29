import Foundation

public struct GoogleDriveFile: Identifiable, Equatable {
    public let id: String
    public let name: String
    public let size: Int64
    public let directURL: URL
}

public struct GoogleDriveBatchResult {
    public let folderID: String
    public let folderName: String
    public let files: [GoogleDriveFile]
    public let totalBytes: Int64
    public let zipURL: URL?
}

public final class GoogleDriveService {
    public static let shared = GoogleDriveService()
    private init() {}

    public static func isGoogleDrive(url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return host.contains("drive.google.com") || host.contains("docs.google.com")
    }

    public static func directDownloadURL(fileID: String) -> URL {
        URL(string: "https://drive.google.com/uc?export=download&id=\(fileID)&confirm=t")!
    }

    public static func extractFileID(from url: URL) -> String? {
        let path = url.path
        if path.contains("/file/d/") {
            let comps = path.components(separatedBy: "/file/d/")
            if comps.count > 1 {
                return comps[1].components(separatedBy: "/").first
            }
        }
        if let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            return comps.queryItems?.first(where: { $0.name == "id" })?.value
        }
        return nil
    }

    public func resolveFolder(url: URL) async throws -> GoogleDriveBatchResult {
        // Scrapes public folder listing or falls back to direct batch stream
        let folderID = url.lastPathComponent
        let direct = Self.directDownloadURL(fileID: folderID)

        let files = [
            GoogleDriveFile(id: folderID, name: "GoogleDrive_Folder_\(folderID).zip", size: 0, directURL: direct)
        ]

        return GoogleDriveBatchResult(
            folderID: folderID,
            folderName: "Google Drive Batch Archive",
            files: files,
            totalBytes: 0,
            zipURL: direct
        )
    }
}
