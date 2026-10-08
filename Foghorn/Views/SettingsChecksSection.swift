import SwiftUI

// MARK: - Checks

struct SettingsChecksSection: View {
    @ObservedObject var settings: AppSettings
    @Binding var newHost: String
    @Binding var customHostsExpanded: Bool
    let palette: DesignPalette

    /// macOS states the real battery mapping from `ProbeEngine.effectiveInterval` (#155); iOS can't keep a
    /// foreground cadence in the background at all, so say what actually happens (#156).
    private static var intervalHelper: String {
        #if os(iOS)
        "While Foghorn is open. In the background, iOS runs checks about every 15 minutes and decides exactly when."
        #else
        "On battery: 2s→4s, 5s→7.5s, 10s and 30s→8s."
        #endif
    }

    var body: some View {
        SettingsSectionCard(tab: .checks, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsOptionRow(
                        label: "Base interval",
                        palette: palette,
                        helper: Self.intervalHelper
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
