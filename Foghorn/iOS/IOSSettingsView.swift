import SwiftUI

/// iOS equivalent of macOS `SettingsView`: same `TabView` idiom per DESIGN.md
/// ("One native TabView — each promise section is a tab"), same `SettingsTab`
/// labels/symbols/promise captions, native iOS tab bar chrome instead of the
/// macOS windowed-pane sizing machinery (`applySettingsWindowChrome`,
/// `paneHeight`, etc. are AppKit/NSWindow-specific and have no iOS equivalent
/// — a full-screen sheet with a native tab bar replaces them).
///
/// Checks tab (#130) reuses `SettingsChecksSection` unmodified — it has no
/// AppKit dependency. Interrupt tab (#132) reuses `SettingsInterruptSection`
/// with its menu-bar toggle `#if os(macOS)`-guarded out (no menu bar on
/// iOS). Help tab (#133) reuses `SettingsHelpPrivacySection`, with "Show in
/// Finder" guarded out and "View outage log…" presenting `OutageLogView`
/// (#134, already had an iOS branch, just wasn't in the FoghorniOS target)
/// as a sheet instead of `AppNavigation.openOutageLog()`'s NSWindow.
/// Remembers is dropped entirely (#131): its only two features are
/// launch-at-login (SMAppService, no iOS concept of it) and in-app update
/// checking (Sparkle, macOS-only — iOS updates via the App Store). Nothing
/// in that section has an iOS equivalent, so there's no screen to build;
/// it would just be permanently empty.
struct IOSSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .checks
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var alertService = AlertService.shared
    @State private var newHost = ""
    @State private var customHostsExpanded = false
    @State private var showOutageLog = false

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    private var iOSTabs: [SettingsTab] {
        SettingsTab.allCases.filter { $0 != .remembers }
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ForEach(iOSTabs) { tab in
                    tabPane(tab)
                        .tabItem {
                            Label(tab.title, systemImage: tab.symbolName)
                        }
                        .tag(tab)
                        .accessibilityIdentifier(tab.tabAccessibilityIdentifier)
                }
            }
            .background(palette.graphite)
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

    @ViewBuilder
    private func tabPane(_ tab: SettingsTab) -> some View {
        ScrollView {
            switch tab {
            case .checks:
                SettingsChecksSection(
                    settings: settings,
                    newHost: $newHost,
                    customHostsExpanded: $customHostsExpanded,
                    palette: palette
                )
                .padding(12)
            case .interrupt:
                SettingsInterruptSection(settings: settings, alertService: alertService, palette: palette)
                    .padding(12)
            case .help:
                SettingsHelpPrivacySection(palette: palette) {
                    showOutageLog = true
                }
                .padding(12)
            default:
                SettingsSectionCard(tab: tab, palette: palette) {
                    placeholderContent(for: tab)
                }
                .padding(12)
            }
        }
        .background(palette.graphite)
    }

    /// Only .remembers has no iOS screen — see the type doc comment.
    @ViewBuilder
    private func placeholderContent(for tab: SettingsTab) -> some View {
        SettingsHelperText(text: "Coming soon.", palette: palette)
            .accessibilityIdentifier(tab.sectionAccessibilityIdentifier + ".placeholder")
    }
}
