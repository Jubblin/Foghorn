import Foundation

#if canImport(AppKit)
import AppKit
#endif

#if canImport(UIKit)
import UIKit
#endif

enum AppLinks {
    static let privacyPolicy = URL(string: "https://jubblin.github.io/Foghorn/privacy.html")!
    static let support = URL(string: "https://github.com/Jubblin/Foghorn/issues")!
    static let reportIssue = URL(string: "https://github.com/Jubblin/Foghorn/issues/new/choose")!
    static let releases = URL(string: "https://github.com/Jubblin/Foghorn/releases")!
    static let appcast = URL(string: "https://github.com/Jubblin/Foghorn/releases/download/sparkle-appcast/appcast.xml")!
    static let documentation = URL(string: "https://jubblin.github.io/Foghorn/")!

    static func openInBrowser(_ url: URL) {
#if canImport(AppKit)
        NSWorkspace.shared.open(url)
#else
        UIApplication.shared.open(url)
#endif
    }
}
