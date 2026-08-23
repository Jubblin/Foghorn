import XCTest
@testable import Foghorn

final class AppUpdateModelsTests: XCTestCase {
    func testVersionOrderingNumeric() {
        XCTAssertEqual(AppVersionOrdering.compare("0.2.19", "0.2.20"), .orderedAscending)
        XCTAssertEqual(AppVersionOrdering.compare("0.2.20", "0.2.19"), .orderedDescending)
        XCTAssertEqual(AppVersionOrdering.compare("0.2.20", "0.2.20"), .orderedSame)
        XCTAssertTrue(AppVersionOrdering.isNewer("0.3.0", than: "0.2.20"))
        XCTAssertFalse(AppVersionOrdering.isNewer("0.2.20", than: "0.2.20"))
    }

    func testVersionOrderingPrefersHigherPatchOverBuildSuffix() {
        XCTAssertTrue(AppVersionOrdering.isNewer("0.2.20", than: "0.2.19-build.37"))
        XCTAssertEqual(AppVersionOrdering.compare("0.2.20", "0.2.20-build.1"), .orderedAscending)
    }

    func testPreferredDownloadURLPicksArchitecture() {
        let release = AppRelease(
            tagName: "v0.2.20",
            name: "Foghorn v0.2.20",
            htmlURL: URL(string: "https://github.com/Jubblin/Foghorn/releases/tag/v0.2.20")!,
            isPrerelease: false,
            publishedAt: nil,
            assets: [
                AppReleaseAsset(
                    name: "Foghorn-0.2.20-amd64.dmg",
                    downloadURL: URL(string: "https://example.com/amd64.dmg")!
                ),
                AppReleaseAsset(
                    name: "Foghorn-0.2.20-arm64.dmg",
                    downloadURL: URL(string: "https://example.com/arm64.dmg")!
                )
            ]
        )

        XCTAssertEqual(
            release.preferredDownloadURL(architecture: .arm64)?.absoluteString,
            "https://example.com/arm64.dmg"
        )
        XCTAssertEqual(
            release.preferredDownloadURL(architecture: .amd64)?.absoluteString,
            "https://example.com/amd64.dmg"
        )
    }

    func testLatestOfficialUpdateSkipsPrereleaseAndBuildTags() {
        let releases = sampleReleases()

        let update = AppUpdateSelection.latestAvailableUpdate(
            in: releases,
            currentVersion: "0.2.20",
            includePrereleases: false
        )
        XCTAssertEqual(update?.tagName, "v0.2.21")
        XCTAssertNil(
            AppUpdateSelection.latestAvailableUpdate(
                in: releases,
                currentVersion: "0.2.21",
                includePrereleases: false
            )
        )
    }

    func testLatestAvailableUpdateIncludesPrereleasesWhenEnabled() {
        let update = AppUpdateSelection.latestAvailableUpdate(
            in: sampleReleases(),
            currentVersion: "0.2.21",
            includePrereleases: true
        )
        XCTAssertEqual(update?.tagName, "v0.2.21-build.40")
    }

    func testContinuousBuildFlag() {
        let continuous = AppRelease(
            tagName: "v0.2.20-build.38",
            name: nil,
            htmlURL: URL(string: "https://example.com/c")!,
            isPrerelease: true,
            publishedAt: nil,
            assets: []
        )
        XCTAssertTrue(continuous.isContinuousBuild)
        XCTAssertEqual(continuous.versionString, "0.2.20-build.38")
    }

    private func sampleReleases() -> [AppRelease] {
        [
            AppRelease(
                tagName: "v0.2.21-build.40",
                name: nil,
                htmlURL: URL(string: "https://example.com/build")!,
                isPrerelease: true,
                publishedAt: nil,
                assets: []
            ),
            AppRelease(
                tagName: "v0.2.21",
                name: nil,
                htmlURL: URL(string: "https://example.com/official")!,
                isPrerelease: false,
                publishedAt: nil,
                assets: []
            ),
            AppRelease(
                tagName: "v0.2.20",
                name: nil,
                htmlURL: URL(string: "https://example.com/old")!,
                isPrerelease: false,
                publishedAt: nil,
                assets: []
            )
        ]
    }
}
