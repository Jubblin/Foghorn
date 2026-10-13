import SwiftUI

/// iOS Settings sheet per DESIGN.md → iPhone → Settings sheet (#156): one scroll
/// with the three promise sections in order, instead of a tab bar inside a sheet.
/// Each shared section already draws its own Signal Glass card headed by its
/// promise caption, so they stack as grouped sections without nesting cards.
///
/// Checks (#130) reuses `SettingsChecksSection`. Interrupt (#132) reuses
/// `SettingsInterruptSection` with its menu-bar toggle `#if os(macOS)`-guarded
/// out. Help (#133) reuses `SettingsHelpPrivacySection`, with "Show in Finder"
/// guarded out and "View outage log…" presenting `OutageLogView` (#134) as a
/// sheet. Remembers is dropped (#131): launch at login (SMAppService) and
/// in-app updates (Sparkle) have no iOS equivalent.
struct IOSSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var alertService = AlertService.shared
    @State private var newHost = ""
    @State private var customHostsExpanded = false
    @State private var showOutageLog = false

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    SettingsChecksSection(
                        settings: settings,
                        newHost: $newHost,
                        customHostsExpanded: $customHostsExpanded,
                        palette: palette
                    )
                    SettingsInterruptSection(settings: settings, alertService: alertService, palette: palette)
                    SettingsHelpPrivacySection(palette: palette) {
                        showOutageLog = true
                    }
                }
                .padding(16)
            }
            .background(palette.graphite.ignoresSafeArea())
            .foregroundStyle(palette.fogText)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                customHostsExpanded = !settings.customHosts.isEmpty
                Task { await alertService.refreshAuthorizationStatus() }
            }
            .sheet(isPresented: $showOutageLog) {
                OutageLogView()
            }
        }
    }
}
