import Foundation

/// Whether a satisfied/unsatisfied flip is worth alerting on. Pulled out of
/// `PathProbe`'s callback so the transition rule is testable without a real
/// `NWPathMonitor`.
enum LinkTransition: Equatable {
    case lost
    case restored

    static func decide(previous: Bool?, current: Bool) -> LinkTransition? {
        guard let previous, previous != current else { return nil }
        return current ? .restored : .lost
    }
}

/// Tracks whether background monitoring is confirmed alive, across process
/// restarts, without pretending iOS tells us *why* a process ended (#114 —
/// force-quit and a memory-pressure kill while suspended look identical from
/// here). `markBackgrounded` records "monitoring's fate is now uncertain";
/// `markConfirmedRunning` and `consumePausedFlag` both clear that uncertainty,
/// the difference being which one the caller uses gets to see the result.
enum MonitoringLifecycleTracker {
    private static let key = "iosBackgroundMonitoringUncertain"

    static func markBackgrounded(in defaults: UserDefaults = .standard) {
        defaults.set(true, forKey: key)
    }

    /// Called when a background probe run completes — proof monitoring kept
    /// working across this process's lifetime even though the app was never
    /// foregrounded to confirm it directly.
    static func markConfirmedRunning(in defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: key)
    }

    /// Call exactly once per process, the first time the app becomes active.
    /// Returns whether monitoring's fate was left uncertain by whatever ended
    /// the previous process — the caller's cue to show the paused state —
    /// and clears the flag either way.
    static func consumePausedFlag(in defaults: UserDefaults = .standard) -> Bool {
        let wasUncertain = defaults.bool(forKey: key)
        defaults.set(false, forKey: key)
        return wasUncertain
    }
}
