import Foundation

enum AppArchitecture: String, Equatable {
    case arm64
    case amd64

    static var current: AppArchitecture {
        #if arch(arm64)
        return .arm64
        #else
        return .amd64
        #endif
    }
}

struct AppReleaseAsset: Equatable {
    let name: String
    let downloadURL: URL
}

struct AppRelease: Equatable {
    let tagName: String
    let name: String?
    let htmlURL: URL
    let isPrerelease: Bool
    let publishedAt: Date?
    let assets: [AppReleaseAsset]

    /// Marketing version from tag (`v0.2.20` → `0.2.20`, `v0.2.20-build.38` → `0.2.20-build.38`).
    var versionString: String {
        tagName.hasPrefix("v") ? String(tagName.dropFirst()) : tagName
    }

    /// Prefer official semver tags (`0.2.20`) over continuous `*-build.N` tags.
    var isContinuousBuild: Bool {
        versionString.contains("-build.")
    }

    func preferredDownloadURL(architecture: AppArchitecture = .current) -> URL? {
        let needle = "-\(architecture.rawValue).dmg"
        if let match = assets.first(where: { $0.name.lowercased().hasSuffix(needle) }) {
            return match.downloadURL
        }
        return assets.first(where: { $0.name.lowercased().hasSuffix(".dmg") })?.downloadURL
    }
}

enum AppVersionOrdering {
    /// Compare dotted numeric versions; optional `-build.N` / prerelease suffixes sort after the base.
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = components(lhs)
        let right = components(rhs)
        let count = max(left.numeric.count, right.numeric.count)
        for index in 0 ..< count {
            let leftValue = index < left.numeric.count ? left.numeric[index] : 0
            let rightValue = index < right.numeric.count ? right.numeric[index] : 0
            if leftValue < rightValue { return .orderedAscending }
            if leftValue > rightValue { return .orderedDescending }
        }
        return left.suffix.compare(right.suffix, options: [.numeric, .caseInsensitive])
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    private static func components(_ version: String) -> (numeric: [Int], suffix: String) {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: true)
        let numericPart = String(parts.first ?? "")
        let suffix = parts.count > 1 ? String(parts[1]) : ""
        let numbers = numericPart.split(separator: ".").compactMap { Int($0) }
        return (numbers, suffix)
    }
}
