import SwiftUI
import AppKit
import LocationChangerCore

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var newSSID = ""
    @State private var newLocation = ""

    var body: some View {
        Form {
            if !model.validation.isClean {
                Section {
                    validationWarning
                }
            }

            Section("General") {
                Picker("Fallback location", selection: Binding(
                    get: { model.config.fallback },
                    set: { model.setFallback($0) }
                )) {
                    ForEach(availablePickerItems(), id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                Toggle("Show notifications", isOn: Binding(
                    get: { model.config.notificationsEnabled },
                    set: { model.setNotificationsEnabled($0) }
                ))

                Toggle("Launch at login", isOn: Binding(
                    get: { model.launchAtLoginEnabled },
                    set: { model.setLaunchAtLogin($0) }
                ))
            }

            Section("Rules") {
                if model.config.rules.isEmpty {
                    Text("No rules defined. Add one below.")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                } else {
                    ForEach(model.config.rules) { rule in
                        ruleRow(rule)
                    }
                    .onDelete(perform: model.removeRules)
                }

                HStack {
                    TextField("SSID", text: $newSSID)
                    Picker("", selection: $newLocation) {
                        Text("Select location…").tag("")
                        ForEach(model.availableLocations, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    Button("Add") {
                        model.addRule(ssid: newSSID, location: newLocation)
                        newSSID = ""
                        newLocation = ""
                    }
                    .disabled(newSSID.isEmpty || newLocation.isEmpty)
                }
            }

            Section("Advanced") {
                HStack {
                    Button("Open config file") {
                        NSWorkspace.shared.activateFileViewerSelecting([model.configFileURL])
                    }
                    Button("Refresh locations") {
                        model.refreshAvailableLocations()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { model.refreshAvailableLocations() }
    }

    private var validationWarning: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Some rules point to locations that don't exist in System Settings", systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.callout.bold())
            if model.validation.fallbackIsUnknown {
                Text("Fallback '\(model.config.fallback)' is not a defined network location.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(model.validation.unknownRuleLocations) { rule in
                Text("SSID '\(rule.ssid)' → missing location '\(rule.location)'")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text("Fix by changing the location to one of the picker options, or define it in System Settings › Network › Locations.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private func availablePickerItems() -> [String] {
        var names = model.availableLocations
        if !names.contains(model.config.fallback) {
            names.insert(model.config.fallback, at: 0)
        }
        return names
    }

    private func ruleRow(_ rule: Rule) -> some View {
        HStack {
            TextField("SSID", text: Binding(
                get: { rule.ssid },
                set: { model.updateRule(id: rule.id, ssid: $0) }
            ))
            Picker("", selection: Binding(
                get: { rule.location },
                set: { model.updateRule(id: rule.id, location: $0) }
            )) {
                ForEach(pickerLocations(for: rule.location), id: \.self) { name in
                    Text(name).tag(name)
                }
            }
            .labelsHidden()
        }
    }

    private func pickerLocations(for current: String) -> [String] {
        var names = model.availableLocations
        if !names.contains(current) {
            names.insert(current, at: 0)
        }
        return names
    }
}
