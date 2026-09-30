import SwiftUI

/// iOS equivalent of macOS `SettingsView`: same `TabView` idiom per DESIGN.md
/// ("One native TabView — each promise section is a tab"), same `SettingsTab`
/// labels/symbols/promise captions, native iOS tab bar chrome instead of the
/// macOS windowed-pane sizing machinery (`applySettingsWindowChrome`,
/// `paneHeight`, etc. are AppKit/NSWindow-specific and have no iOS equivalent
/// — a full-screen sheet with a native tab bar replaces them).
///
/// Checks tab (#130) reuses `SettingsChecksSection` unmodified — it has no
/// AppKit dependency. Remembers/Interrupt/Help (#131/#132/#133) still show
/// the "Coming soon" placeholder.
struct IOSSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .checks
    @ObservedObject private var settings = AppSettings.shared
    @State private var newHost = ""
    @State private var customHostsExpanded = false

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedTab) {
                ForEach(SettingsTab.allCases) { tab in
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
            }
        }
    }

    @ViewBuilder
    private func tabPane(_ tab: SettingsTab) -> some View {
        ScrollView {
            if tab == .checks {
                SettingsChecksSection(
                    settings: settings,
                    newHost: $newHost,
                    customHostsExpanded: $customHostsExpanded,
                    palette: palette
                )
                .padding(12)
            } else {
                SettingsSectionCard(tab: tab, palette: palette) {
                    placeholderContent(for: tab)
                }
                .padding(12)
            }
        }
        .background(palette.graphite)
    }

    /// Filled in by #131/#132/#133; this shell only needs somewhere
    /// truthful to point while those land.
    @ViewBuilder
    private func placeholderContent(for tab: SettingsTab) -> some View {
        SettingsHelperText(text: "Coming soon.", palette: palette)
            .accessibilityIdentifier(tab.sectionAccessibilityIdentifier + ".placeholder")
    }
}
