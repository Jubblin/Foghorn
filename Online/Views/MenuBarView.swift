import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var outageLog = OutageLog.shared

    private var status: ConnectivityStatus {
        coordinator.status
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            statusSection
            if !status.probeRows.isEmpty {
                Divider()
                probeSection
            }
            Divider()
            if let last = outageLog.lastRecord {
                outageSection(last)
                Divider()
            }
            actionsSection
        }
        .frame(width: 300)
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
                .foregroundStyle(DesignTokens.mutedLichen)
        }
        .padding()
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
    }

    private func outageSection(_ record: OutageRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last outage")
                .font(.caption)
                .foregroundStyle(DesignTokens.mutedLichen)
            Text(record.reasonDetail)
                .font(.body)
            Text("\(formatted(date: record.startedAt)) · \(record.durationDescription)")
                .font(DesignTokens.dataFont)
                .foregroundStyle(DesignTokens.mutedLichen)
        }
        .padding()
    }

    private var actionsSection: some View {
        Group {
            Button("Check now") {
                coordinator.refreshNow()
            }
            Button("View outage log…") {
                openWindow(id: "outage-log")
                NSApp.activate(ignoringOtherApps: true)
            }
            Button("Reveal log file in Finder") {
                outageLog.revealInFinder()
            }
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit Online") {
                coordinator.quit()
            }
        }
    }

    private func formatted(date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}
