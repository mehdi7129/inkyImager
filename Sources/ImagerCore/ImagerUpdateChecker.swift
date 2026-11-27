import Foundation

public struct ImagerUpdate: Equatable {
    public let version: String
    public let downloadURL: URL
}

public enum ImagerUpdateChecker {
    private static let endpoint = URL(string: "https://api.github.com/repos/mehdi7129/inkyImager/releases/latest")!
    private static let downloadBase = "https://github.com/mehdi7129/inkyImager/releases/download"

    public static func check(installedVersion: String) async throws -> ImagerUpdate? {
        guard versionComponents(installedVersion) != nil else { throw CheckError.invalidInstalledVersion }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.httpShouldSetCookies = false
        configuration.timeoutIntervalForResource = 15
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        var request = URLRequest(url: endpoint, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 10)
        request.setValue("no-cache, no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("inkyImager", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, response.statusCode == 200, response.url == endpoint else {
            throw CheckError.invalidRelease
        }
        return try resolve(data: data, installedVersion: installedVersion)
    }

    static func resolve(data: Data, installedVersion: String) throws -> ImagerUpdate? {
        guard let installed = versionComponents(installedVersion) else { throw CheckError.invalidInstalledVersion }
        guard let release = try? JSONDecoder().decode(Release.self, from: data),
              !release.draft, !release.prerelease, release.tag_name.hasPrefix("v") else {
            throw CheckError.invalidRelease
        }
        let version = String(release.tag_name.dropFirst())
        guard let latest = versionComponents(version) else { throw CheckError.invalidRelease }
        guard installed.lexicographicallyPrecedes(latest) else { return nil }

        let installer = "inkyImager-\(version)-Universal.dmg"
        let canonical = "\(downloadBase)/\(release.tag_name)/\(installer)"
        guard release.assets.contains(where: {
            $0.name == installer && $0.state == "uploaded" && $0.size > 0 && $0.browser_download_url == canonical
        }), let downloadURL = URL(string: canonical) else {
            throw CheckError.missingInstaller
        }
        return ImagerUpdate(version: version, downloadURL: downloadURL)
    }

    private static func versionComponents(_ version: String) -> [Int]? {
        let parts = version.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 3 else { return nil }
        let values = parts.compactMap { part -> Int? in
            guard !part.isEmpty, part.count == 1 || part.first != "0",
                  part.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
            return Int(part)
        }
        return values.count == 3 ? values : nil
    }

    private struct Release: Decodable {
        let tag_name: String
        let draft: Bool
        let prerelease: Bool
        let assets: [Asset]

        struct Asset: Decodable {
            let name: String
            let state: String
            let size: Int64
            let browser_download_url: String
        }
    }

    enum CheckError: LocalizedError {
        case invalidInstalledVersion, invalidRelease, missingInstaller

        var errorDescription: String? {
            switch self {
            case .invalidInstalledVersion:
                return ImagerLocalization.text("Cette installation n’indique pas sa version. Installez la version publiée sur GitHub.")
            case .invalidRelease:
                return ImagerLocalization.text("La version publiée sur GitHub n’a pas pu être vérifiée. Réessayez plus tard.")
            case .missingInstaller:
                return ImagerLocalization.text("Le DMG Universal de la nouvelle version n’est pas encore disponible.")
            }
        }
    }
}
