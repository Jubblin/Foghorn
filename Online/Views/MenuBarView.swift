import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var outageLog = OutageLog.shared

    private var status: ConnectivityStatus {
        coordinator.status
    }

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            if !status.probeRows.isEmpty {
                paletteDivider
                probeSection
            }
            paletteDivider
            if let last = outageLog.lastRecord {
                outageSection(last)
                paletteDivider
            }
            actionsSection
        }
        .frame(width: 300)
        .foregroundStyle(palette.fogText)
        .background(palette.graphite)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var paletteDivider: some View {
        Divider().overlay(palette.divider)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: status.state.menuBarSymbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(coordinator.iconColor)
                Text(status.statusSentence)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Last check: \(formatted(date: status.lastCheck))")
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.signalGlass)
    }

    private var probeSection: some View {
        VStack(spacing: 0) {
            ForEach(Array(status.probeRows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label)
                        .font(DesignTokens.dataFont)
                        .foregroundStyle(DesignTokens.probeBlue)
                    Spacer()
                    Text(row.detail)
                        .font(DesignTokens.dataFont)
                        .foregroundStyle(row.success ? DesignTokens.truthGreen : DesignTokens.outageRed)
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }
        }
        .background(palette.abyss.opacity(colorScheme == .dark ? 0.55 : 0.35))
    }

    private func outageSection(_ record: OutageRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last outage")
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
            Text(record.reasonDetail)
                .font(.body)
            Text("\(formatted(date: record.startedAt)) · \(record.durationDescription)")
                .font(DesignTokens.dataFont)
                .foregroundStyle(palette.mutedLichen)
        }
        .padding()
    }

    private var actionsSection: some View {
        VStack(spacing: 0) {
            PopoverActionRow(title: "Check now", palette: palette) {
                coordinator.refreshNow()
            }
            PopoverActionRow(title: "View outage log…", palette: palette) {
                openWindow(id: "outage-log")
                NSApp.activate(ignoringOtherApps: true)
            }
            PopoverActionRow(title: "Reveal log file in Finder", palette: palette) {
                outageLog.revealInFinder()
            }
            PopoverSettingsRow(palette: palette)
            paletteDivider
            PopoverActionRow(title: "Quit Online", palette: palette) {
                coordinator.quit()
            }
        }
        .padding(.vertical, 4)
        .background(palette.graphite)
    }

    private func formatted(date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}

private struct PopoverActionLabel: View {
    let title: String
    let palette: DesignPalette
    let isHovered: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13))
            .foregroundStyle(palette.fogText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 5)
            .background(isHovered ? palette.actionHover : Color.clear)
            .contentShape(Rectangle())
    }
}

private struct PopoverSettingsRow: View {
    let palette: DesignPalette

    @State private var isHovered = false

    var body: some View {
        SettingsLink {
            PopoverActionLabel(title: "Settings…", palette: palette, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

private struct PopoverActionRow: View {
    let title: String
    let palette: DesignPalette
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            PopoverActionLabel(title: title, palette: palette, isHovered: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
