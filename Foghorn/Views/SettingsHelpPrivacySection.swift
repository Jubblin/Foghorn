import SwiftUI

// MARK: - Help & privacy (+ about)

struct SettingsHelpPrivacySection: View {
    let palette: DesignPalette
    var showOutageLog: (() -> Void)?

    var body: some View {
        SettingsSectionCard(tab: .help, palette: palette) {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    SettingsHelperText(
                        text: "Foghorn monitors connectivity locally — no personal data collected. "
                            + "Updates use a signed appcast over HTTPS.",
                        palette: palette
                    )

                    HStack(spacing: 6) {
                        linkButton("Privacy", url: AppLinks.privacyPolicy, identifier: "settings.link.privacy")
                        linkSeparator
                        linkButton("Docs", url: AppLinks.documentation, identifier: "settings.link.docs")
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

                VStack(alignment: .leading, spacing: 6) {
                    Button("View outage log…") {
                        if let showOutageLog {
                            showOutageLog()
                        }
#if os(macOS)
                        else {
                            AppNavigation.openOutageLog()
                        }
#endif
                    }
                    .accessibilityIdentifier("settings.viewOutageLog")

#if os(macOS)
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
#endif
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
