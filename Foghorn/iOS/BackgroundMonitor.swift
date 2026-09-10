import Foundation

#if canImport(UIKit)
import BackgroundTasks

/// Background-side connectivity monitoring for the iPhone build (#115), separate
/// from `AppCoordinator`'s foreground `ProbeEngine` loop, which iOS suspends the
/// moment the app backgrounds. Two independent signals, per the design in #114:
/// `PathProbe`'s push callback for instant link-level alerts, and a periodic
/// `BGAppRefreshTask` for the deep probes (gateway/DNS/HTTP) that catch a
/// captive portal or upstream outage a healthy link alone won't show.
/// Not `@MainActor` as a whole: `registerBackgroundTask()` must run synchronously
/// from `FoghorniOSApp.init()`, which isn't actor-isolated. Only the two methods
/// that call into `AlertService` (itself `@MainActor`) need isolation, applied
/// at that narrower scope instead.
final class BackgroundMonitor {
    static let shared = BackgroundMonitor()

    static let refreshTaskIdentifier = "com.online.menu.ios.refresh"

    /// No guaranteed floor from iOS — this is a request, not a schedule (#114).
    private static let refreshInterval: TimeInterval = 15 * 60

    private let pathProbe = PathProbe()
    private var lastDeepProbeHealthy: Bool?

    private init() {}

    /// Must run before the app finishes launching — `BGTaskScheduler` requires
    /// registration at that point, so `FoghorniOSApp.init()` is the call site.
    func registerBackgroundTask() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.refreshTaskIdentifier, using: nil) { [weak self] task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            Task { @MainActor in
                self?.handleRefresh(task: refreshTask)
            }
        }
    }

    func start() {
        scheduleNextRefresh()

        pathProbe.onStatusChange = { [weak self] satisfied in
            Task { @MainActor in
                self?.handlePathStatusChange(satisfied: satisfied)
            }
        }
    }

    func appDidEnterBackground() {
        MonitoringLifecycleTracker.markBackgrounded()
    }

    private var hasConsumedPausedStateThisLaunch = false

    /// Safe to call on every `.active` transition, not just the first: only the
    /// first call this process actually consumes the flag and can return true,
    /// so a view that re-checks on every foreground doesn't need its own
    /// once-per-launch bookkeeping.
    func consumePausedState() -> Bool {
        guard !hasConsumedPausedStateThisLaunch else { return false }
        hasConsumedPausedStateThisLaunch = true
        return MonitoringLifecycleTracker.consumePausedFlag()
    }

    /// `PathProbe.onStatusChange` only fires on a genuine flip (it tracks its own
    /// last-known state), so `satisfied` here is already the new value after a
    /// real transition — no separate before/after tracking needed on this side.
    @MainActor
    private func handlePathStatusChange(satisfied: Bool) {
        if satisfied {
            AlertService.shared.notifyBackgroundConnectivityRestored()
        } else {
            AlertService.shared.notifyBackgroundConnectivityLost(reason: "Network link dropped")
        }
    }

    private func scheduleNextRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.refreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.refreshInterval)
        try? BGTaskScheduler.shared.submit(request)
    }

    private func handleRefresh(task: BGAppRefreshTask) {
        scheduleNextRefresh()

        let work = Task {
            await runDeepProbes()
            task.setTaskCompleted(success: true)
        }
        task.expirationHandler = {
            work.cancel()
        }
    }

    private func runDeepProbes() async {
        let pathGateways = pathProbe.gatewayHostStrings()
        async let gateway = GatewayProbe.probe(pathGateways: pathGateways)
        async let dns = DNSProbe.probe()
        async let http = HTTPProbe.probePrimary()

        let gatewayResult = await gateway
        let dnsResult = await dns
        let httpResult = await http
        let healthy = gatewayResult.success && dnsResult.success && httpResult.success

        switch LinkTransition.decide(previous: lastDeepProbeHealthy, current: healthy) {
        case .lost:
            await AlertService.shared.notifyBackgroundConnectivityLost(reason: "Internet check failed")
        case .restored:
            await AlertService.shared.notifyBackgroundConnectivityRestored()
        case nil:
            break
        }
        lastDeepProbeHealthy = healthy

        MonitoringLifecycleTracker.markConfirmedRunning()
    }
}
#endif
