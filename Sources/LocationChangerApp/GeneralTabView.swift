import SwiftUI
import AppKit
import LocationChangerCore

struct GeneralTabView: View {
    @EnvironmentObject var model: AppModel

    var body: some View {
        Form {
            Section("Fallback") {
                fallbackPicker
                Text("Applied when the current Wi-Fi SSID doesn't match any rule — including when Wi-Fi is off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Notifications") {
                Toggle("Show a banner when the location changes", isOn: Binding(
                    get: { model.config.notificationsEnabled },
                    set: { model.setNotificationsEnabled($0) }
                ))
                Text("The banner appears only when the location actually changes — not on every Wi-Fi event.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch LocationChanger at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
                Text("Registers the app via Service Management so it restarts after logout or reboot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @ViewBuilder
    private var fallbackPicker: some View {
        if model.availableLocations.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                Text("No network locations defined yet.")
                    .foregroundStyle(.secondary)
                openSystemSettingsButton
            }
        } else if model.validation.fallbackIsUnknown {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Saved fallback '\(model.config.fallback)' is not a defined network location.")
                        .foregroundStyle(.primary)
                }
                HStack {
                    Picker("Pick a defined location", selection: Binding(
                        get: { model.availableLocations.contains(model.config.fallback) ? model.config.fallback : (model.availableLocations.first ?? "") },
                        set: { model.setFallback($0) }
                    )) {
                        ForEach(model.availableLocations, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    openSystemSettingsButton
                }
            }
        } else {
            HStack {
                Picker("Fallback location", selection: Binding(
                    get: { model.config.fallback },
                    set: { model.setFallback($0) }
                )) {
                    ForEach(model.availableLocations, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                openSystemSettingsButton
            }
        }
    }

    private var openSystemSettingsButton: some View {
        Button {
            if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                NSWorkspace.shared.open(url)
            }
        } label: {
            Label("System Settings", systemImage: "arrow.up.forward.square")
        }
        .help("Open Network settings to create or rename locations.")
    }
}
