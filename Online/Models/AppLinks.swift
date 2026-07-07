import AppKit
import Foundation

enum AppLinks {
    static let privacyPolicy = URL(string: "https://jubblin.github.io/online/privacy.html")!
    static let support = URL(string: "https://github.com/Jubblin/online/issues")!
    static let reportIssue = URL(string: "https://github.com/Jubblin/online/issues/new/choose")!

    static func openInBrowser(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
