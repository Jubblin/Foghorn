import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var alertService = AlertService.shared
    @State private var selectedTab: SettingsTab = .interrupt
    @State private var newHost = ""
    @State private var launchError: String?
    @State private var customHostsExpanded = UITestConfiguration.isActive
    @State private var paneHeights: [SettingsTab: CGFloat] = [:]
    @State private var launchStatus: LaunchAtLoginService.Status = .unsupported
    @State private var tabStripHeight: CGFloat = 30

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tabPane(.interrupt) {
                SettingsInterruptSection(settings: settings, alertService: alertService, palette: palette)
            }
            .tabItem {
                Label(SettingsTab.interrupt.title, systemImage: SettingsTab.interrupt.symbolName)
            }
            .tag(SettingsTab.interrupt)
            .accessibilityIdentifier(SettingsTab.interrupt.tabAccessibilityIdentifier)

            tabPane(.checks) {
                SettingsChecksSection(
                    settings: settings,
                    newHost: $newHost,
                    customHostsExpanded: $customHostsExpanded,
                    palette: palette
                )
            }
            .tabItem {
                Label(SettingsTab.checks.title, systemImage: SettingsTab.checks.symbolName)
            }
            .tag(SettingsTab.checks)
            .accessibilityIdentifier(SettingsTab.checks.tabAccessibilityIdentifier)

            tabPane(.remembers) {
                SettingsRemembersSection(
                    settings: settings,
                    launchError: $launchError,
                    launchStatus: $launchStatus,
                    palette: palette
                )
            }
            .tabItem {
                Label(SettingsTab.remembers.title, systemImage: SettingsTab.remembers.symbolName)
            }
            .tag(SettingsTab.remembers)
            .accessibilityIdentifier(SettingsTab.remembers.tabAccessibilityIdentifier)

            tabPane(.help) {
                SettingsHelpPrivacySection(palette: palette) {
                    AppNavigation.openOutageLog()
                }
            }
            .tabItem {
                Label(SettingsTab.help.title, systemImage: SettingsTab.help.symbolName)
            }
            .tag(SettingsTab.help)
            .accessibilityIdentifier(SettingsTab.help.tabAccessibilityIdentifier)
        }
        .frame(width: 480, height: paneHeight)
        .background(palette.graphite)
        .foregroundStyle(palette.fogText)
        .modifier(SettingsWindowBackgroundModifier(color: palette.graphite))
        .onAppear {
            // Never assign LaunchAtLoginService status into settings.launchAtLogin:
            // the toggle is the user's intent, and its didSet persists it, so doing
            // so overwrote the preference whenever macOS had dropped the login item
            // (#101). Restoring the registration is AppCoordinator's job.
            launchStatus = LaunchAtLoginService.restoreIfNeeded(intent: settings.launchAtLogin)
            customHostsExpanded = !settings.customHosts.isEmpty || UITestConfiguration.isActive
            applySettingsWindowChrome()
            Task { await alertService.refreshAuthorizationStatus() }
        }
        .onChange(of: selectedTab) { _, _ in
            applySettingsWindowChrome()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            applySettingsWindowChrome()
            Task { await alertService.refreshAuthorizationStatus() }
        }
        .onChange(of: settings.customHosts) { _, hosts in
            if !hosts.isEmpty {
                customHostsExpanded = true
            }
        }
        .onChange(of: colorScheme) { _, _ in
            applySettingsWindowChrome()
        }
    }

    /// DESIGN.md: title is always "Settings"; fill window with graphite (no system white gap).
    private func applySettingsWindowChrome() {
        #if canImport(AppKit)
        let background = NSColor(palette.graphite)
        DispatchQueue.main.async {
            let tabTitles: Set<String> = ["Interrupt", "Checks", "Remembers", "Help", "Settings"]
            for window in NSApp.windows where window.isVisible {
                guard window.styleMask.contains(.titled) else { continue }
                if tabTitles.contains(window.title) {
                    window.title = "Settings"
                    window.backgroundColor = background
                    window.contentView?.wantsLayer = true
                    window.contentView?.layer?.backgroundColor = background.cgColor
                    // Never let macOS auto-reopen Settings on next launch — a restored
                    // window skips the showSettingsWindow: chrome setup and renders
                    // with corrupted tabs.
                    window.isRestorable = false
                }
            }
        }
        #endif
    }

    private func tabPane<Content: View>(
        _ tab: SettingsTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ScrollView {
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .background(
                    GeometryReader { proxy in
                        Color.clear.preference(key: PaneHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .scrollBounceBehavior(.basedOnSize)
        .onPreferenceChange(PaneHeightKey.self) { height in
            paneHeights[tab] = height
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            GeometryReader { proxy in
                Color.clear.preference(key: PaneRenderedHeightKey.self, value: proxy.size.height)
            }
        )
        .onPreferenceChange(PaneRenderedHeightKey.self) { rendered in
            // The tab strip sits inside the frame we set, so the pane renders shorter
            // than requested. Measure that difference instead of hard-coding it.
            guard rendered > 0, tab == selectedTab else { return }
            tabStripHeight = max(0, paneHeight - rendered)
        }
        .background(palette.graphite)
    }

    /// Window fits the selected tab so the bottom gutter matches the sides (#77).
    /// Capped so a long custom-host list scrolls instead of stretching the window.
    private var paneHeight: CGFloat {
        min((paneHeights[selectedTab] ?? 420) + tabStripHeight, 520)
    }
}

/// `containerBackground(for: .window)` needs macOS 15; fall back to plain background on 14.
private struct SettingsWindowBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        #if os(macOS)
        if #available(macOS 15.0, *) {
            content.containerBackground(color, for: .window)
        } else {
            content
        }
        #else
        content
        #endif
    }
}

// MARK: - Interrupt

private struct PaneHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

private struct PaneRenderedHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// MARK: - Remembers

private struct SettingsRemembersSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject private var updateService = AppUpdateService.shared
    @Binding var launchError: String?
    @Binding var launchStatus: LaunchAtLoginService.Status
    let palette: DesignPalette
    @State private var isCheckingForUpdates = false

    var body: some View {
        SettingsSectionCard(tab: .remembers, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Toggle("Launch at login", isOn: $settings.launchAtLogin)
                        .accessibilityIdentifier("settings.launchAtLogin")
                        .onChange(of: settings.launchAtLogin) { _, enabled in
                            do {
                                try LaunchAtLoginService.setEnabled(enabled)
                                launchError = nil
                            } catch {
                                launchError = error.localizedDescription
                            }
                            launchStatus = LaunchAtLoginService.status
                        }

                    if let launchError {
                        Text(launchError)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.outageRed)
                    }

                    // The toggle shows intent; say so when macOS is not honouring it,
                    // rather than silently reading the difference back as "off" (#101).
                    if settings.launchAtLogin, launchStatus == .requiresApproval {
                        SettingsLoginApprovalNotice(palette: palette)
                    }
                }

                SettingsBandDivider(palette: palette)

                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Check for updates automatically", isOn: $settings.automaticUpdatesEnabled)
                        .accessibilityIdentifier("settings.automaticUpdates")

                    Toggle("Include pre-release updates", isOn: $settings.includePrereleaseUpdates)
                        .accessibilityIdentifier("settings.includePrereleaseUpdates")

                    SettingsHelperText(
                        text: settings.includePrereleaseUpdates
                            ? "Installs updates in-app, including the prerelease channel."
                            : "Installs official updates in-app when a newer release is available.",
                        palette: palette
                    )

                    HStack(spacing: 8) {
                        Button(isCheckingForUpdates ? "Checking…" : "Check for Updates…") {
                            Task {
                                isCheckingForUpdates = true
                                _ = await updateService.checkForUpdates(userInitiated: true)
                                isCheckingForUpdates = false
                                updateService.presentManualCheckResult()
                            }
                        }
                        .disabled(isCheckingForUpdates || updateService.status == .checking)
                        .accessibilityIdentifier("settings.checkForUpdates")

                        if case .available = updateService.status {
                            Button("Install Update…") {
                                updateService.openAvailableUpdate()
                            }
                            .accessibilityIdentifier("settings.downloadUpdate")
                        }
                    }

                    SettingsHelperText(text: updateService.statusSummary, palette: palette)
                }
            }
        }
    }
}

