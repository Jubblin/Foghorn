import Combine
import SwiftUI

@MainActor
final class AppCoordinator: ObservableObject {
    /// Healthy stays quieter than alerts, but must remain findable on Tahoe’s
    /// transparent menu bar (0.25 read as “missing” on many displays).
    @Published private(set) var menuBarOpacity: Double = 0.55
    @Published private(set) var iconColor: Color = .secondary

    let probeEngine = ProbeEngine()
    let stateMachine = ConnectivityStateMachine()
    let outageLog = OutageLog.shared
    let alertService = AlertService.shared
    let wakeObserver = WakeObserver()

    private var hasStarted = false

    var status: ConnectivityStatus {
        stateMachine.status
    }

    func start() {
        guard !hasStarted else { return }
        hasStarted = true

        wakeObserver.onWake = { [weak self] in
            Task { @MainActor in
                self?.stateMachine.setWakeGrace(seconds: 15)
            }
        }
        wakeObserver.start()

        if let ongoing = outageLog.lastRecord, ongoing.isOngoing {
            stateMachine.adoptOngoingOutage(ongoing)
            updatePresentation()
        }

        AppUpdateService.shared.startAutomaticChecksIfNeeded()

        stateMachine.onOutageStarted = { [weak self] record in
            Task { @MainActor in
                await self?.alertService.requestAuthorizationIfNeeded()
                self?.outageLog.startOutage(record)
                self?.alertService.notifyOutage(record: record)
                self?.updatePresentation()
            }
        }

        stateMachine.onOutageEnded = { [weak self] record, duration in
            Task { @MainActor in
                self?.outageLog.endOutage(record)
                self?.alertService.notifyRestored(duration: duration)
                self?.updatePresentation()
            }
        }

        stateMachine.onStateChanged = { [weak self] _ in
            Task { @MainActor in
                self?.updatePresentation()
            }
        }

        probeEngine.start { [weak self] snapshot in
            Task { @MainActor in
                self?.stateMachine.process(snapshot: snapshot)
            }
        }

        updatePresentation()
    }

    func stop() {
        probeEngine.stop()
        wakeObserver.stop()
        AppUpdateService.shared.stopAutomaticChecks()
    }

    func refreshNow() {
        Task {
            await probeEngine.runTickNow()
        }
    }

    func quit() {
        #if canImport(AppKit)
        NSApplication.shared.terminate(nil)
        #else
        // iOS apps can't/shouldn't quit programmatically. Keep as no-op.
        #endif
    }

    private func updatePresentation() {
        switch stateMachine.status.state {
        case .healthy:
            menuBarOpacity = 0.55
            iconColor = DesignTokens.truthGreen
        case .degraded:
            menuBarOpacity = 0.95
            iconColor = DesignTokens.warningAmber
        case .outage:
            menuBarOpacity = 1.0
            iconColor = DesignTokens.outageRed
        case .recovering:
            menuBarOpacity = 0.85
            iconColor = DesignTokens.recoveringGray
        }
    }
}
