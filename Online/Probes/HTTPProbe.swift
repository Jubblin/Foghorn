import Foundation

enum HTTPProbe {
    private static var testSession: URLSession?
    private static let defaultSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5
        config.timeoutIntervalForResource = 5
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private static let customSession: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 8
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    private static var session: URLSession {
        testSession ?? defaultSession
    }

    static func injectSessionForTesting(_ session: URLSession?) {
        testSession = session
    }

    static func probe(urlString: String, kind: ProbeKind, session: URLSession? = nil) async -> SingleProbeResult {
        let session = session ?? self.session
        guard let url = URL(string: urlString) else {
            return SingleProbeResult(kind: kind, success: false, detail: "invalid url")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        do {
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return SingleProbeResult(kind: kind, success: false, detail: "non-http response")
            }

            let code = http.statusCode
            let success = (200 ... 399).contains(code)
            var detail = "HTTP \(code)"

            if urlString.contains("captive.apple.com"), code == 200 {
                detail = "captive portal check OK"
            } else if code >= 300, code < 400 {
                detail = "redirect HTTP \(code) — captive possible"
            }

            return SingleProbeResult(kind: kind, success: success, detail: detail)
        } catch {
            return SingleProbeResult(kind: kind, success: false, detail: error.localizedDescription)
        }
    }

    static func probePrimary() async -> SingleProbeResult {
        await probe(urlString: "https://captive.apple.com/hotspot-detect.html", kind: .httpPrimary)
    }

    static func probeSecondary() async -> SingleProbeResult {
        await probe(urlString: "https://cloudflare.com", kind: .httpSecondary)
    }

    static func probeCustom(host: String) async -> SingleProbeResult {
        let normalized = host.hasPrefix("http") ? host : "https://\(host)"
        return await probe(urlString: normalized, kind: .custom, session: customSession)
    }
}
