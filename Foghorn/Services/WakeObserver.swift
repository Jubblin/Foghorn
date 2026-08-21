import Combine

#if canImport(AppKit)
import AppKit
#endif

@MainActor
final class WakeObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    var onWake: (() -> Void)?

    func start() {
#if canImport(AppKit)
        cancellable = NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onWake?()
            }
#else
        // No wake hooks on iOS; the app can instead observe scene lifecycle.
        // Keeping this as a no-op preserves shared Coordinator code.
        cancellable = nil
#endif
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
