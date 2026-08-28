import AppKit
import Combine
import SwiftUI

/// AppKit menu-bar item. Replaces SwiftUI `MenuBarExtra`, which is unreliable on
/// macOS 26/27 (Control Center / Window Server compositing).
@MainActor
final class StatusItemController: NSObject, ObservableObject {
    static let shared = StatusItemController()

    private static let autosaveName = "FoghornMenuBarItem"

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var coordinator: AppCoordinator?
    private var cancellables = Set<AnyCancellable>()
    private var settingsCancellable: AnyCancellable?
    private var eventMonitor: Any?
    private var isInstalled = false

    func install(coordinator: AppCoordinator) {
        self.coordinator = coordinator
        guard !isInstalled else {
            applyVisibility(AppSettings.shared.showInMenuBar)
            refreshIcon()
            return
        }
        isInstalled = true

        clearPersistedVisibility()

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.isVisible = true
        item.autosaveName = Self.autosaveName
        item.isVisible = true

        if let button = item.button {
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.setAccessibilityLabel("Foghorn")
            // Ensure a first-frame glyph even before Combine delivers state.
            button.title = "●"
        }

        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 300, height: 1)
        popover.delegate = self
        self.popover = popover

        bindCoordinator(coordinator)
        bindSettings()
        refreshIcon()
        applyVisibility(AppSettings.shared.showInMenuBar)

        // Override deferred system restore of a persisted hidden state.
        DispatchQueue.main.async { [weak self] in
            self?.applyVisibility(AppSettings.shared.showInMenuBar)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.applyVisibility(AppSettings.shared.showInMenuBar)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.warnIfSystemIsHidingIcon()
        }
    }

    private func warnIfSystemIsHidingIcon() {
        guard AppSettings.shared.showInMenuBar else { return }
        guard let statusItem, let button = statusItem.button else { return }

        let frame = button.window?.frame ?? .zero
        let offScreen = frame.height > 0 && (frame.origin.y < 0 || frame.maxY < 1)
        let invisibleFlag = !statusItem.isVisible

        guard offScreen || invisibleFlag else { return }

        let alert = NSAlert()
        alert.messageText = "Foghorn’s menu bar icon is hidden"
        alert.informativeText = """
        Foghorn is running (alerts still work), but macOS is not showing its menu bar icon.

        Open System Settings → Menu Bar and turn Foghorn on under “Allow in the menu bar”.
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open Menu Bar Settings")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.ControlCenter-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    func applyVisibility(_ visible: Bool) {
        guard let statusItem else { return }
        if visible {
            clearPersistedVisibility()
        }
        statusItem.isVisible = visible
    }

    private func clearPersistedVisibility() {
        UserDefaults.standard.removeObject(forKey: "NSStatusItem Visible \(Self.autosaveName)")
    }

    private func bindCoordinator(_ coordinator: AppCoordinator) {
        cancellables.removeAll()
        Publishers.CombineLatest3(
            coordinator.$menuBarOpacity,
            coordinator.$iconColor.map { NSColor($0).cgColor },
            coordinator.stateMachine.$status.map(\.state)
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] _, _, _ in
            self?.refreshIcon()
        }
        .store(in: &cancellables)
    }

    private func bindSettings() {
        settingsCancellable = AppSettings.shared.$showInMenuBar
            .receive(on: RunLoop.main)
            .sink { [weak self] visible in
                self?.applyVisibility(visible)
                if !visible {
                    self?.closePopover()
                }
            }
    }

    private func refreshIcon() {
        guard let coordinator, let button = statusItem?.button else { return }
        let symbol = coordinator.status.state.menuBarSymbol
        let tint = NSColor(coordinator.iconColor).withAlphaComponent(coordinator.menuBarOpacity)

        let baseConfig = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let colorConfig = baseConfig.applying(.init(paletteColors: [tint]))
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: coordinator.status.state.displayName),
              let configured = base.withSymbolConfiguration(colorConfig) else {
            button.title = "●"
            button.image = nil
            button.contentTintColor = tint
            return
        }

        // Must NOT be a template image — templates ignore state colors and render as
        // black/white menu-bar chrome. Bake the traffic-light tint into the bitmap.
        let icon = NSImage(size: configured.size, flipped: false) { rect in
            configured.draw(in: rect)
            return true
        }
        icon.isTemplate = false
        button.image = icon
        button.title = ""
        button.contentTintColor = nil
        button.appearsDisabled = false
        button.toolTip = "Foghorn — \(coordinator.status.state.displayName)"
        button.setAccessibilityLabel("Foghorn — \(coordinator.status.state.displayName)")
    }

    private func makePopoverContent() -> NSViewController? {
        guard let coordinator else { return nil }
        let root = MenuBarView()
            .environmentObject(coordinator)
            .preferredColorScheme(AppSettings.shared.appearancePreference.colorScheme)
            .id(AppSettings.shared.appearancePreference)
        let hosting = NSHostingController(rootView: root)
        hosting.sizingOptions = [.intrinsicContentSize]
        return hosting
    }

    @objc
    private func togglePopover(_ sender: Any?) {
        guard AppSettings.shared.showInMenuBar else { return }
        if popover?.isShown == true {
            closePopover()
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let statusItem, let button = statusItem.button, let popover else { return }
        popover.contentViewController = makePopoverContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        statusItem.button?.isHighlighted = true
        NSApp.activate(ignoringOtherApps: true)
        startEventMonitor()
    }

    /// Dismisses the status-item popover if it is showing.
    /// Call before opening Settings / other key windows so they can become key.
    func dismissPopover() {
        closePopover()
    }

    private func closePopover() {
        popover?.performClose(nil)
        statusItem?.button?.isHighlighted = false
        stopEventMonitor()
    }

    private func startEventMonitor() {
        stopEventMonitor()
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.closePopover()
            }
        }
    }

    private func stopEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }
}

extension StatusItemController: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        statusItem?.button?.isHighlighted = false
        stopEventMonitor()
    }
}

enum AppNavigation {
    static let openOutageLogNotification = Notification.Name("foghorn.openOutageLog")

    @MainActor
    private static var outageLogWindow: NSWindow?

    @MainActor
    private static var settingsCloseObserver: NSObjectProtocol?

    /// Titles the Settings scene / chrome may briefly use before forcing "Settings".
    private static let settingsWindowTitles: Set<String> = [
        "Settings", "Interrupt", "Checks", "Remembers", "Help"
    ]

    /// Opens the SwiftUI `Settings` scene only.
    /// Do **not** host `SettingsView` in a plain `NSWindow` — that drops preferences
    /// tab chrome and looks like corrupted tabs (icons/labels wrong or doubled).
    @MainActor
    static func openSettings() {
        AppSettings.shared.showInMenuBar = true
        StatusItemController.shared.applyVisibility(true)
        // Transient popover must resign key first or showSettingsWindow: is a no-op.
        StatusItemController.shared.dismissPopover()

        let previousPolicy = NSApp.activationPolicy()
        if previousPolicy != .regular {
            NSApp.setActivationPolicy(.regular)
        }

        // Defer past popover teardown; retry if the scene is slow to materialize.
        DispatchQueue.main.async {
            // showSettingsWindow: no-ops unless the app is already active — activate
            // first, not after (see #59).
            NSApp.activate(ignoringOtherApps: true)
            showSettingsScene(remainingAttempts: 4)
            scheduleAccessoryRestore(previousPolicy: previousPolicy)
        }
    }

    @MainActor
    static func openOutageLog() {
        StatusItemController.shared.dismissPopover()
        NotificationCenter.default.post(name: openOutageLogNotification, object: nil)

        if let existing = outageLogWindow, existing.isVisible {
            bringToFront(existing)
            return
        }

        // Imperative fallback — SwiftUI openWindow only works after Settings/Window scenes load.
        let root = OutageLogView()
            .preferredColorScheme(AppSettings.shared.appearancePreference.colorScheme)
        let hosting = NSHostingController(rootView: root)
        let window = NSWindow(contentViewController: hosting)
        window.title = "Outage Log"
        window.setContentSize(NSSize(width: 800, height: 440))
        window.center()
        window.isReleasedWhenClosed = false
        window.isRestorable = false
        bringToFront(window)
        outageLogWindow = window
    }

    @MainActor
    private static func bringToFront(_ window: NSWindow) {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private static func showSettingsScene(remainingAttempts: Int) {
        if let existing = settingsWindow() {
            bringToFront(existing)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        _ = NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)

        guard remainingAttempts > 1 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            showSettingsScene(remainingAttempts: remainingAttempts - 1)
        }
    }

    /// The Settings scene window, visible or not. `showSettingsWindow:` builds the
    /// window but does not always order it on screen, so callers must bring it front.
    @MainActor
    private static func settingsWindow() -> NSWindow? {
        NSApp.windows.first { window in
            window.styleMask.contains(.titled)
                && settingsWindowTitles.contains(window.title)
        }
    }

    @MainActor
    private static func scheduleAccessoryRestore(previousPolicy: NSApplication.ActivationPolicy) {
        guard previousPolicy == .accessory else { return }

        if let settingsCloseObserver {
            NotificationCenter.default.removeObserver(settingsCloseObserver)
        }

        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            // Fires for every window, including the status-item popover. Only a real
            // user window closing should hand the app back to accessory mode.
            guard let closing = note.object as? NSWindow, isUserWindow(closing) else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 50_000_000)
                guard !hasVisibleUserWindow() else { return }
                NSApp.setActivationPolicy(.accessory)
                if let settingsCloseObserver {
                    NotificationCenter.default.removeObserver(settingsCloseObserver)
                    self.settingsCloseObserver = nil
                }
            }
        }
    }

    /// Closes any Settings / Outage Log window macOS auto-restored from a previous
    /// session (its "reopen windows" state-restoration feature). This app is a
    /// menu-bar accessory utility — it should never show a window at launch unless
    /// the user explicitly asks (`-open-settings` / UI test flags). An auto-restored
    /// window also skips the chrome setup in `showSettingsScene`, which is what
    /// produces corrupted preferences tabs.
    @MainActor
    static func closeAutoRestoredWindows() {
        for window in NSApp.windows where window.isVisible {
            guard window.styleMask.contains(.titled) else { continue }
            if settingsWindowTitles.contains(window.title) || window.title == "Outage Log" {
                window.close()
            }
        }
    }

    @MainActor
    private static func hasVisibleUserWindow() -> Bool {
        NSApp.windows.contains { window in
            guard window.isVisible, window.canBecomeKey else { return false }
            return isUserWindow(window)
        }
    }

    private static func isUserWindow(_ window: NSWindow) -> Bool {
        settingsWindowTitles.contains(window.title) || window.title == "Outage Log"
    }
}
