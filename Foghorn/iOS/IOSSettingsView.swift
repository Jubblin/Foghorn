import SwiftUI

/// iOS equivalent of macOS `SettingsView`: same `TabView` idiom per DESIGN.md
/// ("One native TabView — each promise section is a tab"), same `SettingsTab`
/// labels/symbols/promise captions, native iOS tab bar chrome instead of the
/// macOS windowed-pane sizing machinery (`applySettingsWindowChrome`,
/// `paneHeight`, etc. are AppKit/NSWindow-specific and have no iOS equivalent
/// — a full-screen sheet with a native tab bar replaces them).
///
/// This is the shell only (#135): each tab's real content lands in #130
/// (Checks), #131 (Remembers), #132 (Interrupt), #133 (Help). Until then each
/// pane shows its `SettingsSectionCard` promise caption with a "Coming soon"
/// placeholder so the shell is a working, mergeable unit on its own.
struct IOSSettingsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: SettingsTab = .interrupt

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
        }
    }

    private func tabPane(_ tab: SettingsTab) -> some View {
        ScrollView {
            SettingsSectionCard(tab: tab, palette: palette) {
                placeholderContent(for: tab)
            }
            .padding(12)
        }
        .background(palette.graphite)
    }

    /// Filled in by #130/#131/#132/#133; this shell only needs somewhere
    /// truthful to point while those land.
    @ViewBuilder
    private func placeholderContent(for tab: SettingsTab) -> some View {
        SettingsHelperText(text: "Coming soon.", palette: palette)
            .accessibilityIdentifier(tab.sectionAccessibilityIdentifier + ".placeholder")
    }
}
