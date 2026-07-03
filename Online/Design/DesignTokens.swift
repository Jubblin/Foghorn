import SwiftUI

enum DesignTokens {
    static let abyss = Color(red: 0.02, green: 0.03, blue: 0.03)
    static let graphite = Color(red: 0.05, green: 0.08, blue: 0.08)
    static let signalGlass = Color(red: 0.11, green: 0.16, blue: 0.16)
    static let fogText = Color(red: 0.84, green: 0.89, blue: 0.85)
    static let truthGreen = Color(red: 0.38, green: 0.82, blue: 0.44)
    static let warningAmber = Color(red: 0.95, green: 0.79, blue: 0.26)
    static let outageRed = Color(red: 1.0, green: 0.30, blue: 0.24)
    static let probeBlue = Color(red: 0.36, green: 0.72, blue: 0.91)
    static let mutedLichen = Color(red: 0.50, green: 0.57, blue: 0.54)
    static let recoveringGray = Color(red: 0.55, green: 0.55, blue: 0.55)

    static let dataFont = Font.system(.caption, design: .monospaced)
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
