import SwiftUI

enum AppearancePreference: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system:
            return "Follow System"
        case .light:
            return "Light"
        case .dark:
            return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
}

struct DesignPalette {
    let abyss: Color
    let graphite: Color
    let signalGlass: Color
    let fogText: Color
    let mutedLichen: Color
    let actionHover: Color
    let divider: Color

    static func palette(colorScheme: ColorScheme) -> DesignPalette {
        switch colorScheme {
        case .dark:
            return DesignPalette(
                abyss: Color(red: 0.02, green: 0.03, blue: 0.03),
                graphite: Color(red: 0.05, green: 0.08, blue: 0.08),
                signalGlass: Color(red: 0.11, green: 0.16, blue: 0.16),
                fogText: Color(red: 0.84, green: 0.89, blue: 0.85),
                mutedLichen: Color(red: 0.50, green: 0.57, blue: 0.54),
                actionHover: Color.white.opacity(0.08),
                divider: Color.white.opacity(0.12)
            )
        case .light:
            return DesignPalette(
                abyss: Color(red: 0.93, green: 0.95, blue: 0.94),
                graphite: Color(red: 0.96, green: 0.97, blue: 0.96),
                signalGlass: Color(red: 0.91, green: 0.94, blue: 0.92),
                fogText: Color(red: 0.09, green: 0.13, blue: 0.12),
                mutedLichen: Color(red: 0.40, green: 0.47, blue: 0.44),
                actionHover: Color.black.opacity(0.06),
                divider: Color.black.opacity(0.10)
            )
        @unknown default:
            return palette(colorScheme: .dark)
        }
    }
}

enum DesignTokens {
    static let truthGreen = Color(red: 0.38, green: 0.82, blue: 0.44)
    static let warningAmber = Color(red: 0.95, green: 0.79, blue: 0.26)
    static let outageRed = Color(red: 1.0, green: 0.30, blue: 0.24)
    static let probeBlue = Color(red: 0.36, green: 0.72, blue: 0.91)
    static let recoveringGray = Color(red: 0.55, green: 0.55, blue: 0.55)

    static let dataFont = Font.system(.caption, design: .monospaced)

    // Legacy aliases used outside the popover.
    static let mutedLichen = Color(red: 0.50, green: 0.57, blue: 0.54)
}

extension ConnectivityStatus {
    var statusSentence: String {
        switch state {
        case .healthy:
            return "Internet is telling the truth"
        case .recovering:
            return "Connection is recovering"
        case .degraded, .outage:
            if let reason = failureReason {
                return reason.message(host: customHost)
            }
            return state == .outage ? "Internet connection is down" : "Connection looks unstable"
        }
    }

    var probeRows: [(label: String, detail: String, success: Bool)] {
        guard let snapshot = lastSnapshot else { return [] }

        var rows: [(String, String, Bool)] = [
            ("PATH", snapshot.pathSatisfied ? "ok" : "fail", snapshot.pathSatisfied),
            ("GATEWAY", snapshot.gatewayOK ? "ok" : "fail", snapshot.gatewayOK),
            ("DNS", snapshot.dnsOK ? "ok" : "fail", snapshot.dnsOK),
            ("HTTP", snapshot.allHTTPOK ? "ok" : "fail", snapshot.allHTTPOK),
        ]

        let customResults = snapshot.customResults
        if !customResults.isEmpty {
            let allCustomOK = snapshot.allCustomOK
            rows.append(("CUSTOM", allCustomOK ? "ok" : "fail", allCustomOK))
        }

        return rows
    }
}
