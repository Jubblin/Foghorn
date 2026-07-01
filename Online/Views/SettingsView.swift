import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var newHost = ""
    @State private var launchError: String?

    var body: some View {
        Form {
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

            Section("About") {
                Text("Online monitors real internet connectivity and alerts when the connection drops. The menu bar icon stays subtle when everything works.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 420)
        .onAppear {
            settings.launchAtLogin = LaunchAtLoginService.isEnabled
        }
    }
}
