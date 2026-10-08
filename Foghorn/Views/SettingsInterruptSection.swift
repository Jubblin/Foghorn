import SwiftUI

struct SettingsInterruptSection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var alertService: AlertService
    let palette: DesignPalette

    var body: some View {
        SettingsSectionCard(tab: .interrupt, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
#if os(macOS)
                    Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                        .accessibilityIdentifier("settings.showInMenuBar")

                    SettingsHelperText(
                        text: """
                        When Off, monitoring continues. On macOS 26+, enable Foghorn under \
                        System Settings → Menu Bar. Recovery: open -a Foghorn --args -open-settings
                        """,
                        palette: palette
                    )
#endif

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
