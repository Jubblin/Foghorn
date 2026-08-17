import SwiftUI

enum AppInfo {
    static var versionString: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }

    /// Build time inferred from the app executable's modification date.
    static var buildDate: Date? {
        guard let executableURL = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executableURL.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }

    static var buildDateString: String {
        guard let buildDate else { return "unknown" }
        return buildDate.formatted(date: .abbreviated, time: .shortened)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable, Hashable {
    case interrupt
    case checks
    case remembers
    case help

    var id: String { rawValue }

    /// Short tab label (full promise names live as quiet captions).
    var title: String {
        switch self {
        case .interrupt: return "Interrupt"
        case .checks: return "Checks"
        case .remembers: return "Remembers"
        case .help: return "Help"
        }
    }

    /// SF Symbol shown above the tab label.
    var symbolName: String {
        switch self {
        case .interrupt: return "bell.badge"
        case .checks: return "antenna.radiowaves.left.and.right"
        case .remembers: return "clock.arrow.circlepath"
        case .help: return "questionmark.circle"
        }
    }

    var promiseCaption: String {
        switch self {
        case .interrupt: return "When to interrupt me"
        case .checks: return "What Foghorn checks"
        case .remembers: return "What Foghorn remembers"
        case .help: return "Help & privacy"
        }
    }

    var tabAccessibilityIdentifier: String {
        "settings.tab.\(rawValue)"
    }

    var sectionAccessibilityIdentifier: String {
        "settings.section.\(rawValue)"
    }
}

/// Quiet promise caption + signalGlass card. Tabs carry navigation weight.
struct SettingsSectionCard<Content: View>: View {
    let tab: SettingsTab
    let palette: DesignPalette
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tab.promiseCaption)
                .font(.caption)
                .foregroundStyle(palette.mutedLichen)
                .accessibilityIdentifier(tab.sectionAccessibilityIdentifier)

            content
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.signalGlass)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

/// Label | control row with optional helper under the control.
struct SettingsOptionRow<Control: View>: View {
    let label: String
    let palette: DesignPalette
    var helper: String?
    @ViewBuilder let control: Control

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 12) {
                Text(label)
                    .font(.body)
                    .foregroundStyle(palette.fogText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                control
            }

            if let helper {
                SettingsHelperText(text: helper, palette: palette)
            }
        }
    }
}

struct SettingsBandDivider: View {
    let palette: DesignPalette

    var body: some View {
        Divider().overlay(palette.divider)
    }
}

struct SettingsHelperText: View {
    let text: String
    let palette: DesignPalette

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(palette.mutedLichen)
            .fixedSize(horizontal: false, vertical: true)
    }
}

struct SettingsSecondaryButtonStyle: ButtonStyle {
    let palette: DesignPalette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundStyle(configuration.isPressed ? palette.fogText : DesignTokens.probeBlue)
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

struct SettingsStatusChip: View {
    let text: String
    let palette: DesignPalette

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(palette.fogText)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(palette.actionHover)
            .clipShape(Capsule())
    }
}
