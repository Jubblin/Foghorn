import AppKit
import Foundation

enum AppLinks {
    static let privacyPolicy = URL(string: "https://jubblin.github.io/online/privacy.html")!
    static let support = URL(string: "https://github.com/Jubblin/online/issues")!
    static let reportIssue = URL(string: "https://github.com/Jubblin/online/issues/new/choose")!
    static let releases = URL(string: "https://github.com/Jubblin/online/releases")!
    static let appcast = URL(string: "https://github.com/Jubblin/online/releases/download/sparkle-appcast/appcast.xml")!

    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
