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

struct SettingsView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var settings = AppSettings.shared
    @State private var newHost = ""
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Menu bar") {
                Toggle("Show in menu bar", isOn: $settings.showInMenuBar)
                Text("When hidden, Online keeps monitoring and sends notifications. Open Settings from the app menu to restore the icon.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Polling") {
                Picker("Base interval", selection: $settings.basePollInterval) {
                    Text("2 seconds").tag(2.0)
                    Text("5 seconds").tag(5.0)
                    Text("10 seconds").tag(10.0)
                    Text("30 seconds").tag(30.0)
                }
                Text("Interval doubles on battery power (max 8s).")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Custom hosts") {
                if settings.customHosts.isEmpty {
                    Text("No custom hosts configured.")
                        .foregroundStyle(.secondary)
                } else {
                    List {
                        ForEach(settings.customHosts, id: \.self) { host in
                            Text(host)
                        }
                        .onDelete(perform: settings.removeCustomHost)
                    }
                    .frame(minHeight: 80, maxHeight: 160)
                }

                HStack {
                    TextField("vpn.company.com", text: $newHost)
                        .textFieldStyle(.roundedBorder)
                    Button("Add") {
                        settings.addCustomHost(newHost)
                        newHost = ""
                    }
                    .disabled(newHost.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                    .onChange(of: settings.launchAtLogin) { _, enabled in
                        do {
                            try LaunchAtLoginService.setEnabled(enabled)
                            launchError = nil
                        } catch {
                            launchError = error.localizedDescription
                            settings.launchAtLogin = LaunchAtLoginService.isEnabled
                        }
                    }

                if let launchError {
                    Text(launchError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Outage log") {
                Button("View outage log…") {
                    openWindow(id: "outage-log")
                    NSApp.activate(ignoringOtherApps: true)
                }
                Text("Stored at \(OutageLog.shared.filePath)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            Section("About") {
                Text("Online monitors real internet connectivity and alerts when the connection drops. The menu bar icon stays subtle when everything works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Version", value: AppInfo.versionString)
                LabeledContent("Built", value: AppInfo.buildDateString)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 500)
        .onAppear {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
        }
    }
}
