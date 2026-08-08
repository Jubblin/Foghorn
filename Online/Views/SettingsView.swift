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

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            tabPane {
                SettingsInterruptSection(settings: settings, alertService: alertService, palette: palette)
            }
            .tabItem {
                Label(SettingsTab.interrupt.title, systemImage: SettingsTab.interrupt.symbolName)
            }
            .tag(SettingsTab.interrupt)
            .accessibilityIdentifier(SettingsTab.interrupt.tabAccessibilityIdentifier)

            tabPane {
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

            tabPane {
                SettingsRemembersSection(
                    settings: settings,
                    launchError: $launchError,
                    palette: palette
                )
            }
            .tabItem {
                Label(SettingsTab.remembers.title, systemImage: SettingsTab.remembers.symbolName)
            }
            .tag(SettingsTab.remembers)
            .accessibilityIdentifier(SettingsTab.remembers.tabAccessibilityIdentifier)

            tabPane {
                SettingsHelpPrivacySection(palette: palette)
            }
            .tabItem {
                Label(SettingsTab.help.title, systemImage: SettingsTab.help.symbolName)
            }
            .tag(SettingsTab.help)
            .accessibilityIdentifier(SettingsTab.help.tabAccessibilityIdentifier)
        }
        .frame(width: 480, height: 420)
        .background(palette.graphite)
        .foregroundStyle(palette.fogText)
        .modifier(SettingsWindowBackgroundModifier(color: palette.graphite))
        .onAppear {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
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

    private func tabPane<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            content()
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.graphite)
    }
}

/// `containerBackground(for: .window)` needs macOS 15; fall back to plain background on 14.
private struct SettingsWindowBackgroundModifier: ViewModifier {
    let color: Color

    func body(content: Content) -> some View {
        if #available(macOS 15.0, *) {
            content.containerBackground(color, for: .window)
        } else {
            content
        }
    }
}

// MARK: - Interrupt

private struct SettingsInterruptSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var alertService: AlertService
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(tab: .interrupt, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                        .accessibilityIdentifier("settings.showInMenuBar")

                    SettingsHelperText(
                        text: """
                        When Off, monitoring continues. On macOS 26+, enable Online under \
                        System Settings → Menu Bar. Recovery: open -a Online --args -open-settings
                        """,
                        palette: palette
                    )

                    SettingsOptionRow(label: "Appearance", palette: palette) {
                        Picker("Appearance", selection: $settings.appearancePreference) {
                            ForEach(AppearancePreference.allCases) { preference in
                                Text(preference.displayName)
                                    .tag(preference)
                                    .accessibilityLabel(preference.accessibilityName)
                                    .accessibilityIdentifier("settings.appearance.\(preference.rawValue)")
                            }
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                        .accessibilityIdentifier("settings.appearancePicker")
                    }
                }

                SettingsBandDivider(palette: palette)

                HStack(alignment: .center, spacing: 12) {
                    Text("Notifications")
                        .font(.body)
                        .foregroundStyle(palette.fogText)
                    SettingsStatusChip(
                        text: alertService.authorizationDisplay.statusText,
                        palette: palette
                    )
                    .accessibilityHint(notificationAccessibilityHint)
                    Spacer(minLength: 8)
                    notificationAction
                }
            }
        }
    }

    @ViewBuilder
    private var notificationAction: some View {
        switch alertService.authorizationDisplay {
        case .granted:
            EmptyView()
        case .notDetermined:
            Button("Enable alerts") {
                Task { await alertService.requestAuthorizationIfNeeded() }
            }
            .accessibilityIdentifier("settings.enableAlerts")
        case .denied:
            Button("Open Notification Settings") {
                AlertService.openSystemNotificationSettings()
            }
            .accessibilityIdentifier("settings.openNotificationSettings")
        }
    }

    private var notificationAccessibilityHint: String {
        switch alertService.authorizationDisplay {
        case .granted:
            return "macOS alert permission is granted"
        case .notDetermined:
            return "Alert permission has not been requested yet"
        case .denied:
            return "Alert permission is denied in System Settings"
        }
    }
}

// MARK: - Checks

private struct SettingsChecksSection: View {
    @ObservedObject var settings: AppSettings
    @Binding var newHost: String
    @Binding var customHostsExpanded: Bool
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(tab: .checks, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsOptionRow(
                        label: "Base interval",
                        palette: palette,
                        helper: "Doubles on battery (max 8s)."
                    ) {
                        Picker("Base interval", selection: $settings.basePollInterval) {
                            Text("2s").tag(2.0)
                            Text("5s").tag(5.0)
                            Text("10s").tag(10.0)
                            Text("30s").tag(30.0)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(maxWidth: 220)
                        .accessibilityIdentifier("settings.baseIntervalPicker")
                    }
                }

                SettingsBandDivider(palette: palette)

                Group {
                    if UITestConfiguration.isActive {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Custom hosts")
                                .font(.body)
                                .foregroundStyle(palette.fogText)
                            customHostsContent
                        }
                    } else {
                        DisclosureGroup(isExpanded: $customHostsExpanded) {
                            customHostsContent
                        } label: {
                            Text("Custom hosts")
                                .font(.body)
                                .foregroundStyle(palette.fogText)
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("settings.customHosts")
            }
        }
    }

    @ViewBuilder
    private var customHostsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            if settings.customHosts.isEmpty {
                SettingsHelperText(text: "No custom hosts configured.", palette: palette)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(settings.customHosts.enumerated()), id: \.element) { index, host in
                        if index > 0 {
                            Divider().overlay(palette.divider)
                        }
                        HStack(spacing: 8) {
                            Text(host)
                                .font(DesignTokens.dataFont)
                                .foregroundStyle(palette.fogText)
                                .accessibilityIdentifier("settings.customHost.\(host)")
                            Spacer(minLength: 8)
                            Button(role: .destructive) {
                                removeHost(host)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(palette.mutedLichen)
                            .accessibilityLabel("Remove \(host)")
                        }
                        .padding(.vertical, 6)
                    }
                }
                .frame(maxHeight: 120)
            }

            HStack(spacing: 8) {
                Group {
                    if UITestConfiguration.isActive {
                        TextField("vpn.company.com", text: $newHost)
                            .textFieldStyle(.plain)
                    } else {
                        TextField("vpn.company.com", text: $newHost)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                .accessibilityIdentifier("settings.customHostField")
                .accessibilityLabel("Custom host")
                Button("Add") {
                    settings.addCustomHost(newHost)
                    newHost = ""
                    customHostsExpanded = true
                }
                .accessibilityIdentifier("settings.customHostAdd")
                .disabled(newHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(.top, 4)
    }

    private func removeHost(_ host: String) {
        guard let index = settings.customHosts.firstIndex(of: host) else { return }
        settings.removeCustomHost(at: IndexSet(integer: index))
    }
}

// MARK: - Remembers

private struct SettingsRemembersSection: View {
    @ObservedObject var settings: AppSettings
    @Binding var launchError: String?
    let palette: DesignPalette

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
                                settings.launchAtLogin = LaunchAtLoginService.isEnabled
                            }
                        }

                    if let launchError {
                        Text(launchError)
                            .font(.caption)
                            .foregroundStyle(DesignTokens.outageRed)
                    }
                }

                SettingsBandDivider(palette: palette)

                VStack(alignment: .leading, spacing: 6) {
                    Button("View outage log…") {
                        AppNavigation.openOutageLog()
                    }
                    .accessibilityIdentifier("settings.viewOutageLog")

                    Button("Show in Finder") {
                        OutageLog.shared.revealInFinder()
                    }
                    .buttonStyle(SettingsSecondaryButtonStyle(palette: palette))
                    .accessibilityIdentifier("settings.revealOutageLog")

                    Text(OutageLog.shared.filePath)
                        .font(DesignTokens.dataFont)
                        .foregroundStyle(palette.mutedLichen)
                        .textSelection(.enabled)
                        .accessibilityIdentifier("settings.outageLogPath")
                }
            }
        }
    }
}

// MARK: - Help & privacy (+ about)

private struct SettingsHelpPrivacySection: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var updateService = AppUpdateService.shared
    let palette: DesignPalette
    @State private var isCheckingForUpdates = false

    var body: some View {
        SettingsSectionCard(tab: .help, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsHelperText(
                        text: "Online monitors connectivity locally — no personal data collected. Updates use a signed appcast over HTTPS.",
                        palette: palette
                    )

                    HStack(spacing: 6) {
                        linkButton("Privacy", url: AppLinks.privacyPolicy, identifier: "settings.link.privacy")
                        linkSeparator
                        linkButton("Support", url: AppLinks.support, identifier: "settings.link.support")
                        linkSeparator
                        linkButton("Report", url: AppLinks.reportIssue, identifier: "settings.link.report")
                        Spacer(minLength: 0)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        evidenceRow(label: "Version", value: AppInfo.versionString)
                        evidenceRow(label: "Built", value: AppInfo.buildDateString)
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

    private var linkSeparator: some View {
        Text("·")
            .font(.caption)
            .foregroundStyle(palette.mutedLichen)
    }

    private func evidenceRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
            Spacer(minLength: 0)
            Text(value)
                .font(DesignTokens.dataFont)
                .foregroundStyle(palette.mutedLichen)
                .textSelection(.enabled)
        }
    }

    private func linkButton(_ title: String, url: URL, identifier: String) -> some View {
        Button(title) {
            AppLinks.openInBrowser(url)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DesignTokens.probeBlue)
        .accessibilityIdentifier(identifier)
    }
}
