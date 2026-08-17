import Foundation

protocol AppReleaseFetching: Sendable {
    func fetchReleases() async throws -> [AppRelease]
}

enum AppReleaseFetchError: Error, Equatable {
    case invalidResponse
    case httpStatus(Int)
    case decodingFailed
}

struct GitHubReleaseClient: AppReleaseFetching {
    var session: URLSession = .shared
    var releasesURL = URL(string: "https://api.github.com/repos/Jubblin/online/releases")!

    func fetchReleases() async throws -> [AppRelease] {
        var request = URLRequest(url: releasesURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        request.setValue("Foghorn/\(version)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppReleaseFetchError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw AppReleaseFetchError.httpStatus(http.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let payloads = try decoder.decode([GitHubReleasePayload].self, from: data)
            return payloads.map(\.asAppRelease)
        } catch {
            throw AppReleaseFetchError.decodingFailed
        }
    }
}

private struct GitHubReleasePayload: Decodable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let prerelease: Bool
    let publishedAt: Date?
    let assets: [GitHubAssetPayload]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case htmlURL = "html_url"
        case prerelease
        case publishedAt = "published_at"
        case assets
    }

    var asAppRelease: AppRelease {
        AppRelease(
            tagName: tagName,
            name: name,
            htmlURL: htmlURL,
            isPrerelease: prerelease,
            publishedAt: publishedAt,
            assets: assets.compactMap { asset in
                guard let url = URL(string: asset.browserDownloadURL) else { return nil }
                return AppReleaseAsset(name: asset.name, downloadURL: url)
            }
        )
    }
}

private struct GitHubAssetPayload: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

enum AppUpdateSelection {
    /// Newest release newer than `currentVersion`.
    /// When `includePrereleases` is false, skips GitHub prereleases and continuous `-build.N` tags.
    static func latestAvailableUpdate(
        in releases: [AppRelease],
        currentVersion: String,
        includePrereleases: Bool = false
    ) -> AppRelease? {
        releases
            .filter { includePrereleases || (!$0.isPrerelease && !$0.isContinuousBuild) }
            .filter { AppVersionOrdering.isNewer($0.versionString, than: currentVersion) }
            .sorted { AppVersionOrdering.compare($0.versionString, $1.versionString) == .orderedDescending }
            .first
    }
}
