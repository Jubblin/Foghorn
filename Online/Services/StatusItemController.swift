import AppKit
import Combine
import SwiftUI

/// AppKit menu-bar item. Replaces SwiftUI `MenuBarExtra`, which is unreliable on
/// macOS 26/27 (Control Center / Window Server compositing).
@MainActor
final class StatusItemController: NSObject, ObservableObject {
    static let shared = StatusItemController()

    private static let autosaveName = "OnlineMenuBarItem"

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
            button.setAccessibilityLabel("Online")
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
        alert.messageText = "Online’s menu bar icon is hidden"
        alert.informativeText = """
        Online is running (alerts still work), but macOS is not showing its menu bar icon.

        Open System Settings → Menu Bar and turn Online on under “Allow in the menu bar”.
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
            coordinator.$iconColor,
            coordinator.stateMachine.$status
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
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: coordinator.status.state.displayName),
              let configured = base.withSymbolConfiguration(baseConfig) else {
            button.title = "●"
            button.image = nil
            button.contentTintColor = tint
            return
        }

        // Template + contentTintColor is the most reliable menu-bar rendering path.
        let icon = configured.copy() as? NSImage ?? configured
        icon.isTemplate = true
        button.image = icon
        button.title = ""
        button.contentTintColor = tint
        button.appearsDisabled = false
        button.toolTip = "Online — \(coordinator.status.state.displayName)"
        button.setAccessibilityLabel("Online — \(coordinator.status.state.displayName)")
    }

    private func makePopoverContent() -> NSViewController? {
        guard let coordinator else { return nil }
        let root = MenuBarView()
            .environmentObject(coordinator)
            .preferredColorScheme(AppSettings.shared.appearancePreference.colorScheme)
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
    static let openOutageLogNotification = Notification.Name("online.openOutageLog")

    @MainActor
    private static var outageLogWindow: NSWindow?

    @MainActor
    static func openSettings() {
        AppSettings.shared.showInMenuBar = true
        StatusItemController.shared.applyVisibility(true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    static func openOutageLog() {
        NotificationCenter.default.post(name: openOutageLogNotification, object: nil)

        if let existing = outageLogWindow, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
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
        window.makeKeyAndOrderFront(nil)
        outageLogWindow = window
        NSApp.activate(ignoringOtherApps: true)
    }
}
