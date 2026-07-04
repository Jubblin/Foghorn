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
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var alertService = AlertService.shared
    @State private var newHost = ""
    @State private var launchError: String?

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                SettingsInterruptSection(
                    settings: settings,
                    alertService: alertService,
                    palette: palette
                )
                SettingsChecksSection(
                    settings: settings,
                    newHost: $newHost,
                    palette: palette
                )
                SettingsRemembersSection(
                    settings: settings,
                    launchError: $launchError,
                    palette: palette,
                    openOutageLog: openOutageLog
                )
                SettingsHelpPrivacySection(palette: palette)
                SettingsAboutSection(palette: palette)
            }
            .padding(16)
        }
        .background(palette.graphite)
        .frame(width: 480, height: 560)
        .foregroundStyle(palette.fogText)
        .onAppear {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
            Task { await alertService.refreshAuthorizationStatus() }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await alertService.refreshAuthorizationStatus() }
        }
    }

    private func openOutageLog() {
        openWindow(id: "outage-log")
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Section chrome

private struct SettingsSectionCard<Content: View>: View {
    let title: String
    let palette: DesignPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(palette.fogText)
            content
        }
        .padding(16)
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
        SettingsSectionCard(title: "When to interrupt me", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Show in menu bar", isOn: $settings.showInMenuBar)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Appearance")
                        .font(.subheadline)
                    Picker("Appearance", selection: $settings.appearancePreference) {
                        ForEach(AppearancePreference.allCases) { preference in
                            Text(preference.displayName).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                SettingsHelperText(
                    text: "When hidden, Online keeps monitoring and sends notifications. " +
                        "Open Settings from the app menu to restore the icon.",
                    palette: palette
                )

                Divider().overlay(palette.divider)

                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("Notifications", value: alertService.authorizationDisplay.statusText)
                        .accessibilityHint(notificationAccessibilityHint)

                    if alertService.authorizationDisplay == .denied {
                        Button("Open Notification Settings") {
                            AlertService.openSystemNotificationSettings()
                        }
                    } else if alertService.authorizationDisplay == .notDetermined {
                        SettingsHelperText(
                            text: "Online will ask for alert permission when an outage is detected.",
                            palette: palette
                        )
                    }
                }
            }
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
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "What Online checks", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
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

                Divider().overlay(palette.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Custom hosts")
                        .font(.subheadline)

                    if settings.customHosts.isEmpty {
                        SettingsHelperText(text: "No custom hosts configured.", palette: palette)
                    } else {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(settings.customHosts, id: \.self) { host in
                                HStack {
                                    Text(host)
                                        .font(DesignTokens.dataFont)
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

                    HStack {
                        TextField("vpn.company.com", text: $newHost)
                            .textFieldStyle(.roundedBorder)
                        Button("Add") {
                            settings.addCustomHost(newHost)
                            newHost = ""
                        }
                        .disabled(newHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
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
    let openOutageLog: () -> Void

    var body: some View {
        SettingsSectionCard(title: "What Online remembers", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
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

                Button("View outage log…") {
                    openOutageLog()
                }

                Text("Stored at \(OutageLog.shared.filePath)")
                    .font(DesignTokens.dataFont)
                    .foregroundStyle(palette.mutedLichen)
                    .textSelection(.enabled)
            }
        }
    }
}

// MARK: - Help & privacy

private struct SettingsHelpPrivacySection: View {
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "Help & privacy", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsHelperText(
                    text: "Online does not collect or transmit personal data. Probes run locally.",
                    palette: palette
                )

                VStack(alignment: .leading, spacing: 8) {
                    linkButton("Privacy Policy", url: AppLinks.privacyPolicy)
                    linkButton("Support", url: AppLinks.support)
                    linkButton("Report an issue", url: AppLinks.reportIssue)
                }
            }
        }
    }

    private func linkButton(_ title: String, url: URL) -> some View {
        Button(title) {
            AppLinks.openInBrowser(url)
        }
    }
}

// MARK: - About

private struct SettingsAboutSection: View {
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(title: "About", palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                SettingsHelperText(
                    text: "Online monitors real internet connectivity and alerts when the connection drops. " +
                        "The menu bar icon stays subtle when everything works.",
                    palette: palette
                )
                LabeledContent("Version", value: AppInfo.versionString)
                LabeledContent("Built", value: AppInfo.buildDateString)
            }
        }
    }
}
