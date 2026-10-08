import SwiftUI

/// iPhone home screen per DESIGN.md → iPhone (#156): one verdict surface, the
/// Phone → Router → DNS → Internet ladder with only the failing rung lit, then
/// evidence and the last outage as grouped sections.
struct IOSHomeView: View {
    @EnvironmentObject private var coordinator: AppCoordinator

    var body: some View {
        IOSHomeContent(coordinator: coordinator, stateMachine: coordinator.stateMachine)
    }
}

private struct IOSHomeContent: View {
    let coordinator: AppCoordinator
    @ObservedObject var stateMachine: ConnectivityStateMachine
    @ObservedObject private var outageLog = OutageLog.shared

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showPausedBanner = false
    @State private var showSettings = false
    @State private var isChecking = false
    @State private var evidenceExpandedByUser: Bool?

    /// Evidence folds away once a healthy connection has settled (same clock as the
    /// Mac popover, #106); the last outage stays a day because phone sessions are sparse.
    private static let evidenceQuietAfter: TimeInterval = 5 * 60
    private static let lastOutageWindow: TimeInterval = 24 * 60 * 60

    private var palette: DesignPalette {
        DesignPalette.palette(colorScheme: colorScheme)
    }

    private var mock: String? { UITestConfiguration.mockStatus }

    private var status: ConnectivityStatus {
        mock.flatMap(Self.mockStatus) ?? stateMachine.status
    }

    private var checking: Bool {
        isChecking || mock == "checking"
    }

    private var ladder: LayerLadder {
        LayerLadder(status: status, isChecking: checking)
    }

    private var evidenceExpanded: Binding<Bool> {
        Binding(
            get: { evidenceExpandedByUser ?? status.showsProbeEvidence(quietAfter: Self.evidenceQuietAfter) },
            set: { evidenceExpandedByUser = $0 }
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if showPausedBanner || mock == "paused" {
                        pausedBanner
                    }
                    verdict
                    ladderView
                    if !status.probeRows.isEmpty {
                        evidenceSection
                    }
                    if let last = outageLog.lastRecord,
                       last.isOngoing || last.isRecent(within: Self.lastOutageWindow) {
                        lastOutageSection(last)
                    }
                }
                .padding(16)
            }
            .refreshable { await check() }
            .background(palette.graphite.ignoresSafeArea())
            .foregroundStyle(palette.fogText)
            .navigationTitle("Foghorn")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("home.openSettings")
                }
            }
            .sheet(isPresented: $showSettings) {
                IOSSettingsView()
            }
        }
        .sensoryFeedback(.warning, trigger: status.state) { _, new in new == .outage }
        .onChange(of: status.state) { _, _ in evidenceExpandedByUser = nil }
        .onAppear {
            Task { @MainActor in
                if mock == nil {
                    coordinator.start()
                }
                showPausedBanner = BackgroundMonitor.shared.consumePausedState()
                showSettings = UITestConfiguration.shouldOpenSettings
            }
        }
    }

    private func check() async {
        guard !checking else { return }
        isChecking = true
        await coordinator.refresh()
        isChecking = false
    }

    // MARK: Verdict

    private var verdict: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle()
                    .fill(dotColor)
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
                Text(checking ? "Checking each layer…" : status.statusSentence)
                    .font(DesignTokens.verdictFont)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("home.verdict")
            }
            ViewThatFits(in: .horizontal) {
                HStack {
                    verdictCaption
                    Spacer(minLength: 8)
                    checkNowButton
                }
                VStack(alignment: .leading, spacing: 8) {
                    verdictCaption
                    checkNowButton
                }
            }
            .padding(.leading, 20)
        }
        .padding(12)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var dotColor: Color {
        if checking { return DesignTokens.probeBlue }
        switch status.state {
        case .healthy: return palette.mutedLichen
        case .degraded: return DesignTokens.warningAmber
        case .outage: return DesignTokens.outageRed
        case .recovering: return DesignTokens.recoveringGray
        }
    }

    private var verdictCaption: some View {
        Text(captionText)
            .font(.caption)
            .foregroundStyle(palette.mutedLichen)
    }

    private var captionText: String {
        let checked = Self.time(status.lastCheck)
        if status.state == .outage, let started = status.outageStartedAt {
            return "Down \(Self.shortDuration(Date().timeIntervalSince(started))) · checked \(checked)"
        }
        return "Last check \(checked)"
    }

    private var checkNowButton: some View {
        Button {
            Task { await check() }
        } label: {
            Text(checking ? "Checking" : "Check now")
                .font(.subheadline.weight(.medium))
                .frame(minHeight: 32)
        }
        .buttonStyle(.bordered)
        .tint(palette.fogText)
        .disabled(checking)
        .accessibilityIdentifier("home.checkNow")
    }

    // MARK: Ladder

    private var ladderView: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(ladder.rungs.enumerated()), id: \.element.id) { index, rung in
                rungRow(rung, index: index, count: ladder.rungs.count)
                    .animation(
                        reduceMotion ? nil : .easeOut(duration: 0.2).delay(Double(index) * 0.06),
                        value: rung
                    )
            }
        }
        .padding(.horizontal, 4)
        .accessibilityIdentifier("home.ladder")
    }

    private func rungRow(_ rung: LayerLadder.Rung, index: Int, count: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                VStack(spacing: 0) {
                    Rectangle().fill(index == 0 ? .clear : palette.divider)
                    Rectangle().fill(index == count - 1 ? .clear : palette.divider)
                }
                .frame(width: 2)
                rungMark(rung.state)
            }
            .frame(width: 14)
            .accessibilityHidden(true)

            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 2) {
                    rungName(rung)
                    rungDetail(rung)
                }
                .padding(.vertical, 8)
            } else {
                rungName(rung)
                Spacer(minLength: 8)
                rungDetail(rung)
            }
        }
        .frame(minHeight: 44)
        .opacity(rung.state == .notReached ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rung.layer.title), \(Self.spoken(rung.state)), \(rung.detail)")
    }

    private func rungName(_ rung: LayerLadder.Rung) -> some View {
        Text(rung.layer.title)
            .font(.body.weight(.medium))
            .foregroundStyle(rungTint(rung.state) ?? palette.fogText)
    }

    private func rungDetail(_ rung: LayerLadder.Rung) -> some View {
        Text(rung.detail)
            .font(DesignTokens.dataFont)
            .foregroundStyle(rungTint(rung.state) ?? palette.mutedLichen)
    }

    @ViewBuilder
    private func rungMark(_ state: LayerLadder.RungState) -> some View {
        switch state {
        case .passed:
            Circle().fill(palette.mutedLichen).frame(width: 12, height: 12)
        case .failed:
            Circle().fill(DesignTokens.outageRed).frame(width: 12, height: 12)
        case .degraded:
            Circle().fill(DesignTokens.warningAmber).frame(width: 12, height: 12)
        case .checking:
            Image(systemName: "circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignTokens.probeBlue)
                .background(Circle().fill(palette.graphite))
                .symbolEffect(.pulse, options: .repeating, isActive: !reduceMotion)
        case .notReached, .notChecked, .waiting:
            Circle()
                .strokeBorder(palette.mutedLichen, lineWidth: 2)
                .background(Circle().fill(palette.graphite))
                .frame(width: 12, height: 12)
        }
    }

    /// Failed evidence takes the verdict's tone: amber while degraded, red in an outage.
    private var failureTint: Color {
        status.state == .outage ? DesignTokens.outageRed : DesignTokens.warningAmber
    }

    private func rungTint(_ state: LayerLadder.RungState) -> Color? {
        switch state {
        case .failed: return DesignTokens.outageRed
        case .degraded: return DesignTokens.warningAmber
        default: return nil
        }
    }

    private static func spoken(_ state: LayerLadder.RungState) -> String {
        switch state {
        case .passed: return "working"
        case .failed: return "failed"
        case .degraded: return "degraded"
        case .notReached: return "not reached"
        case .notChecked: return "not checked"
        case .checking: return "checking"
        case .waiting: return "waiting"
        }
    }

    // MARK: Evidence and last outage

    private var evidenceSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            DisclosureGroup(isExpanded: evidenceExpanded) {
                VStack(spacing: 0) {
                    ForEach(Array(status.probeRows.enumerated()), id: \.offset) { index, row in
                        if index > 0 {
                            Divider().overlay(palette.divider)
                        }
                        evidenceRow(row)
                    }
                }
                .padding(.top, 4)
            } label: {
                Text("Evidence")
                    .font(.subheadline)
                    .foregroundStyle(palette.mutedLichen)
                    .frame(minHeight: 44, alignment: .leading)
            }
            .tint(palette.mutedLichen)
            .accessibilityIdentifier("home.evidence")
        }
        .padding(.horizontal, 14)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    @ViewBuilder
    private func evidenceRow(_ row: ProbeRow) -> some View {
        let label = Text(row.label).font(DesignTokens.dataFont).foregroundStyle(palette.mutedLichen)
        let detail = Text(row.detail)
            .font(DesignTokens.dataFont)
            .foregroundStyle(row.success ? palette.fogText : failureTint)
            .textSelection(.enabled)
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 2) { label; detail }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
        } else {
            HStack { label; Spacer(minLength: 12); detail }
                .frame(minHeight: 40)
        }
    }

    private func lastOutageSection(_ record: OutageRecord) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(record.isOngoing ? "Outage · ongoing" : "Last outage")
                .font(.subheadline)
                .foregroundStyle(palette.mutedLichen)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 4) {
                Text(record.reasonDetail)
                    .font(.body)
                Text(outageTimes(record))
                    .font(DesignTokens.dataFont)
                    .foregroundStyle(palette.mutedLichen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(palette.signalGlass)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .accessibilityElement(children: .combine)
    }

    private func outageTimes(_ record: OutageRecord) -> String {
        if let endedAt = record.endedAt {
            return "\(Self.time(record.startedAt)) · ended \(Self.time(endedAt)) · \(record.durationDescription)"
        }
        return "\(Self.time(record.startedAt)) · ongoing · \(record.durationDescription)"
    }

    /// Shown when the previous run ended without a confirmed background probe
    /// or a clean foreground close — most likely force-quit, which iOS gives no
    /// way to keep monitoring through (#114). Honest rather than silent (#115).
    private var pausedBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignTokens.warningAmber)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Monitoring paused")
                    .font(.subheadline.weight(.semibold))
                Text("Foghorn wasn't running in the background. Now that it's open, monitoring has resumed.")
                    .font(.caption)
                    .foregroundStyle(palette.mutedLichen)
            }
            Spacer()
            Button {
                showPausedBanner = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(palette.mutedLichen)
                    .frame(minWidth: 44, minHeight: 44)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(12)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    /// "45s", "3m", "1h 12m": the outage caption reads at a glance.
    static func shortDuration(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval))
        if seconds < 60 { return "\(seconds)s" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes)m" }
        return minutes % 60 == 0 ? "\(minutes / 60)h" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }

    // MARK: UI-testing mock states

    /// Canned statuses for `-ui_testing_mock_status`, so every state can be
    /// screenshotted without breaking a real network (#156).
    private static func mockStatus(_ name: String) -> ConnectivityStatus? {
        func result(_ kind: ProbeKind, _ success: Bool, _ detail: String? = nil, host: String? = nil) -> SingleProbeResult {
            SingleProbeResult(kind: kind, success: success, detail: detail, customHost: host)
        }
        let now = Date()
        var path = true, gateway = true, dns = true, http = true
        var custom: Bool?
        var state = ConnectivityState.healthy
        var reason: FailureReason?
        switch name {
        case "healthy", "paused", "checking":
            break
        default:
            guard let failure = FailureReason(rawValue: name) else { return nil }
            reason = failure
            state = failure == .customHostDown ? .degraded : .outage
            switch failure {
            case .noInterface: path = false; gateway = false; dns = false; http = false
            case .routerUnreachable: gateway = false; dns = false; http = false
            case .dnsFailure: dns = false; http = false
            case .ispOutage, .captivePortalLikely: http = false
            case .customHostDown: custom = false
            }
        }
        var results = [
            result(.path, path, path ? "via en0/wifi" : "no interface"),
            result(.gateway, gateway, gateway ? "192.168.1.1" : "192.168.1.1 timeout"),
            result(.dns, dns),
            result(.httpPrimary, http, reason == .captivePortalLikely ? "redirect HTTP 302 — captive possible" : nil),
            result(.httpSecondary, http)
        ]
        if let custom {
            results.append(result(.custom, custom, host: "vpn.company.com"))
        }
        return ConnectivityStatus(
            state: state,
            lastSnapshot: ProbeSnapshot(timestamp: now, results: results),
            failureReason: reason,
            customHost: custom == nil ? nil : "vpn.company.com",
            lastCheck: now,
            outageStartedAt: state == .outage ? now.addingTimeInterval(-192) : nil,
            healthySince: state == .healthy ? now.addingTimeInterval(-600) : nil
        )
    }
}
