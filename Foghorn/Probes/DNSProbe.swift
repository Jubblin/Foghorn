import Foundation

enum DNSProbe {
    static func probe(hostname: String = "cloudflare.com") async -> SingleProbeResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var hints = addrinfo(
                    ai_flags: AI_ADDRCONFIG,
                    ai_family: AF_UNSPEC,
                    ai_socktype: SOCK_STREAM,
                    ai_protocol: IPPROTO_TCP,
                    ai_addrlen: 0,
                    ai_canonname: nil,
                    ai_addr: nil,
                    ai_next: nil
                )

                var info: UnsafeMutablePointer<addrinfo>?
                let result = getaddrinfo(hostname, nil, &hints, &info)
                defer { if let info { freeaddrinfo(info) } }

                if result == 0, info != nil {
                    continuation.resume(returning: SingleProbeResult(kind: .dns, success: true, detail: hostname))
                } else {
                    let message = String(cString: gai_strerror(result))
                    continuation.resume(returning: SingleProbeResult(kind: .dns, success: false, detail: message))
                }
            }
        }
    }
}
