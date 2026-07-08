import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

enum AppInfo {
    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }

    /// Build time inferred from the app executable's modification date.
    static var buildDate: Date? {
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    static var buildDateString: String {
        guard let buildDate else { return "unknown" }
        return buildDate.formatted(date: .abbreviated, time: .shortened)
    }
}

struct SettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var alertService = AlertService.shared
    @State private var newHost = ""
    @State private var launchError: String?
    @State private var customHostsExpanded = UITestConfiguration.isActive

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsInterruptSection(settings: settings, alertService: alertService, palette: palette)
            SettingsChecksSection(
                settings: settings,
                newHost: $newHost,
                customHostsExpanded: $customHostsExpanded,
                palette: palette
            )
            SettingsRemembersSection(
                settings: settings,
                launchError: $launchError,
                palette: palette
            )
            SettingsHelpPrivacySection(palette: palette)
        }
        .padding(12)
        .frame(width: 480, height: 560)
        .background(palette.graphite)
        .foregroundStyle(palette.fogText)
        .onAppear {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
            customHostsExpanded = !settings.customHosts.isEmpty || UITestConfiguration.isActive
            Task { await alertService.refreshAuthorizationStatus() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await alertService.refreshAuthorizationStatus() }
        }
        .onChange(of: settings.customHosts) { _, hosts in
            if !hosts.isEmpty {
                customHostsExpanded = true
            }
        }
    }
}

// MARK: - Section chrome

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let sectionIdentifier: String
    let palette: DesignPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.fogText)
                .accessibilityIdentifier(sectionIdentifier)
            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsHelperText: View {
    let text: String
    let palette: DesignPalette

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(palette.mutedLichen)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - When to interrupt me

private struct SettingsInterruptSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var alertService: AlertService
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "When to interrupt me", sectionIdentifier: "settings.section.interrupt", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                    .accessibilityIdentifier("settings.showInMenuBar")

                VStack(alignment: .leading, spacing: 4) {
                    Text("Appearance")
                        .font(.subheadline)
                    Picker("Appearance", selection: $settings.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(preference.displayName)
                                .tag(preference)
                                .accessibilityIdentifier("settings.appearance.\(preference.rawValue)")
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityIdentifier("settings.appearancePicker")
                }

                SettingsHelperText(
                    text: "When hidden, monitoring continues. Restore the icon via the app menu → Settings.",
                    palette: palette
                )

                Divider().overlay(palette.divider)

                HStack {
                    LabeledContent("Notifications", value: alertService.authorizationDisplay.statusText)
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

// MARK: - What Online checks

private struct SettingsChecksSection: View {
    @ObservedObject var settings: AppSettings
    @Binding var newHost: String
    @Binding var customHostsExpanded: Bool
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "What Online checks", sectionIdentifier: "settings.section.checks", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Base interval", selection: $settings.basePollInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }

                SettingsHelperText(
                    text: "Interval doubles on battery power (max 8s).",
                    palette: palette
                )

                Group {
                    if UITestConfiguration.isActive {
                        customHostsContent
                    } else {
                        DisclosureGroup("Custom hosts", isExpanded: $customHostsExpanded) {
                            customHostsContent
                        }
                    }
                }
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(settings.customHosts, id: \.self) { host in
                            HStack {
                                Text(host)
                                    .font(DesignTokens.dataFont)
                                    .accessibilityIdentifier("settings.customHost.\(host)")
                                Spacer()
                                Button(role: .destructive) {
                                    removeHost(host)
                                } label: {
                                    Image(systemName: "minus.circle.fill")
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(palette.mutedLichen)
                                .accessibilityLabel("Remove \(host)")
                            }
                        }
                    }
                }
                .frame(maxHeight: 120)
            }

            HStack {
                TextField("vpn.company.com", text: $newHost)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("settings.customHostField")
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

// MARK: - What Online remembers

private struct SettingsRemembersSection: View {
    @ObservedObject var settings: AppSettings
    @Binding var launchError: String?
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "What Online remembers", sectionIdentifier: "settings.section.remembers", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
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

                Button("Reveal outage log in Finder") {
                    OutageLog.shared.revealInFinder()
                }
            }
        }
    }
}

// MARK: - Help & privacy (+ about)

private struct SettingsHelpPrivacySection: View {
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "Help & privacy", sectionIdentifier: "settings.section.help", palette: palette) {
            VStack(alignment: .leading, spacing: 8) {
                SettingsHelperText(
                    text: "Online monitors connectivity locally — no personal data collected or transmitted.",
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

                Divider().overlay(palette.divider)

                LabeledContent("Version", value: AppInfo.versionString)
                LabeledContent("Built", value: AppInfo.buildDateString)
            }
        }
    }

    private var linkSeparator: some View {
        Text("·")
            .font(.caption)
            .foregroundStyle(palette.mutedLichen)
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
