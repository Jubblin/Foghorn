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
            Divider()
            if let last = outageLog.lastRecord {
                outageSection(last)
                Divider()
            }
            actionsSection
        }
        .frame(width: 280)
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: status.state.menuBarSymbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(coordinator.iconColor)
                Text(status.state.displayName)
                    .font(.headline)
            }

            Text("Last check: \(formatted(date: status.lastCheck))")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let reason = status.failureReason {
                Text(reason.message(host: status.customHost))
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
        }
        .padding()
    }

    private func outageSection(_ record: OutageRecord) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Last outage")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(record.reasonDetail)
                .font(.body)
            Text("\(formatted(date: record.startedAt)) · \(record.durationDescription)")
                .font(.caption2)
                .foregroundStyle(.secondary)
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
