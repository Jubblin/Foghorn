import SwiftUI

struct iOSHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator
    @Environment(\.colorScheme) private var colorScheme

    @ObservedObject private var outageLog = OutageLog.shared

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    checkNowButton
                    if !coordinator.status.probeRows.isEmpty {
                        probeSection
                    }
                    if let last = outageLog.lastRecord {
                        lastOutageSection(last)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Foghorn")
        }
        .onAppear {
            Task { @MainActor in
                coordinator.start()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: coordinator.status.state.menuBarSymbol)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(coordinator.iconColor)
                    .font(.system(size: 18, weight: .semibold))

                Text(coordinator.status.statusSentence)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Last check: \(formatted(date: coordinator.status.lastCheck))")
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
        }
        .padding(12)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var checkNowButton: some View {
        Button {
            Task { @MainActor in
                coordinator.refreshNow()
            }
        } label: {
            Text("Check now")
                .font(.body.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(DesignTokens.probeBlue)
    }

    private var probeSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(coordinator.status.probeRows.enumerated()), id: \.offset) { _, row in
                HStack {
                    Text(row.label)
                        .font(DesignTokens.dataFont)
                        .foregroundStyle(DesignTokens.probeBlue)
                    Spacer()
                    Text(row.detail)
                        .font(DesignTokens.dataFont)
                        .foregroundStyle(row.success ? DesignTokens.truthGreen : DesignTokens.outageRed)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(12)
        .background(palette.graphite)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func lastOutageSection(_ record: OutageRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Last outage")
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
            Text(record.reasonDetail)
                .font(.body)
            if let endedAt = record.endedAt {
                Text("\(formatted(date: record.startedAt)) · ended \(formatted(date: endedAt)) · \(record.durationDescription)")
                    .font(DesignTokens.dataFont)
                    .foregroundStyle(palette.mutedLichen)
            } else {
                Text("\(formatted(date: record.startedAt)) · ongoing · \(record.durationDescription)")
                    .font(DesignTokens.dataFont)
                    .foregroundStyle(palette.mutedLichen)
            }
        }
        .padding(12)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func formatted(date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}

