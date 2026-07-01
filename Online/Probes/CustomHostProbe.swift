import Foundation

enum CustomHostProbe {
    static func probe(hosts: [String]) async -> [SingleProbeResult] {
        guard !hosts.isEmpty else { return [] }

        return await withTaskGroup(of: SingleProbeResult.self) { group in
            for host in hosts {
                group.addTask {
                    let result = await HTTPProbe.probeCustom(host: host)
                    return SingleProbeResult(
                        kind: .custom,
                        success: result.success,
                        detail: result.detail,
                        customHost: host
                    )
                }
            }

            var results: [SingleProbeResult] = []
            for await result in group {
                results.append(result)
            }
            return results
        }
    }
}
