import AppKit
import Combine

@MainActor
final class WakeObserver: ObservableObject {
    private var cancellable: AnyCancellable?

    var onWake: (() -> Void)?

    func start() {
        cancellable = NotificationCenter.default.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.onWake?()
            }
    }

    func stop() {
        cancellable?.cancel()
        cancellable = nil
    }
}
