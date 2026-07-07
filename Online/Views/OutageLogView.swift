import SwiftUI

struct OutageLogView: View {
    @ObservedObject private var outageLog = OutageLog.shared
    @State private var sortOrder = [KeyPathComparator(\OutageRecord.startedAt, order: .reverse)]
    @State private var copiedNotice = false

    private var sortedRecords: [OutageRecord] {
        outageLog.records.sorted(using: sortOrder)
    }

    var body: some View {
        VStack(spacing: 0) {
            if outageLog.records.isEmpty {
                ContentUnavailableView {
                    Label("No outages recorded", systemImage: "checkmark.circle")
                } description: {
                    Text("When Online detects a confirmed outage, it will appear here.")
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("outageLog.emptyState")
            } else {
                Table(sortedRecords, sortOrder: $sortOrder) {
                    TableColumn("Started", value: \.startedAt) { record in
                        Text(record.startedAt, format: .dateTime.day().month().hour().minute().second())
                    }
                    .width(min: 140, ideal: 160)

                    TableColumn("Ended") { record in
                        if let endedAt = record.endedAt {
                            Text(endedAt, format: .dateTime.day().month().hour().minute().second())
                        } else {
                            Text("ongoing")
                                .foregroundStyle(DesignTokens.warningAmber)
                        }
                    }
                    .width(min: 140, ideal: 160)

                    TableColumn("Duration", value: \.startedAt) { record in
                        Text(record.durationDescription)
                    }
                    .width(ideal: 72)

                    TableColumn("Failure", value: \.reason.rawValue) { record in
                        Text(record.reason.displayName)
                    }
                    .width(ideal: 140)

                    TableColumn("Detail") { record in
                        Text(record.reasonDetail)
                            .lineLimit(2)
                    }
                    .width(min: 120, ideal: 180)

                    TableColumn("Probes") { record in
                        Text(record.probeSummary ?? "—")
                            .font(DesignTokens.dataFont)
                            .foregroundStyle(DesignTokens.mutedLichen)
                            .lineLimit(2)
                    }
                    .width(min: 160, ideal: 220)
                }
            }

            Divider()

            HStack {
                Text("\(outageLog.records.count) record\(outageLog.records.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.mutedLichen)

                Spacer()

                if copiedNotice {
                    Text("Copied JSON")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button("Reveal in Finder") {
                    outageLog.revealInFinder()
                }

                Button("Copy JSON") {
                    outageLog.copyJSONToPasteboard()
                    copiedNotice = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        copiedNotice = false
                    }
                }
                .disabled(outageLog.records.isEmpty)

                Button("Refresh") {
                    outageLog.reload()
                }
            }
            .padding(12)
        }
        .frame(minWidth: 720, minHeight: 360)
        .onAppear {
            outageLog.reload()
        }
    }
}

#Preview {
    OutageLogView()
}
