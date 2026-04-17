import SwiftUI
import LocationChangerCore

struct RuleEditorSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// nil → add mode. non-nil → edit the rule with this id.
    let existing: Rule?

    @State private var ssid: String
    @State private var location: String
    @State private var knownSSIDs: [String] = []
    @State private var useCustomSSID: Bool = false
    @State private var showHelpSSID = false
    @State private var showHelpLocation = false

    private static let customTag = "__lc_custom_ssid__"

    init(existing: Rule?) {
        self.existing = existing
        _ssid = State(initialValue: existing?.ssid ?? "")
        _location = State(initialValue: existing?.location ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            formBody
            Divider()
            footerBar
        }
        .frame(width: 480)
        .onAppear { onAppearSetup() }
    }

    // MARK: - Setup

    private func onAppearSetup() {
        knownSSIDs = WiFiMonitor.knownSSIDs()
        // Surface the currently-connected SSID if it isn't already in the list.
        if let cur = WiFiMonitor.currentSSID(), !cur.isEmpty, !knownSSIDs.contains(cur) {
            knownSSIDs.insert(cur, at: 0)
        }

        // Initial mode for the SSID field:
        //  - edit with a known value   → picker selected, ssid kept
        //  - edit with an unknown value → custom text with the existing value
        //  - add with known networks   → pre-fill the first known SSID so the
        //                                Add button isn't disabled just because
        //                                the Picker only fires .set on interaction
        //  - add with no known networks → custom text
        if !ssid.isEmpty, !knownSSIDs.contains(ssid) {
            useCustomSSID = true
        } else if ssid.isEmpty {
            if let first = knownSSIDs.first {
                ssid = first
                useCustomSSID = false
            } else {
                useCustomSSID = true
            }
        }

        // Seed a default location for the add flow.
        if location.isEmpty, let first = model.availableLocations.first {
            location = first
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(existing == nil ? "Add rule" : "Edit rule").font(.headline)
            Spacer()
        }
        .padding(12)
    }

    // MARK: - Form

    private var formBody: some View {
        Form {
            Section {
                ssidInput
            } header: {
                Text("Wi-Fi SSID").font(.caption).foregroundStyle(.secondary)
            } footer: {
                if duplicateSSID {
                    Label("Another rule already uses this SSID. First match wins, so that rule would fire and this one would never apply.", systemImage: "exclamationmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section {
                locationInput
            } header: {
                Text("Target network location").font(.caption).foregroundStyle(.secondary)
            } footer: {
                if !location.isEmpty, !model.availableLocations.contains(location) {
                    Label("'\(location)' is not a defined location in System Settings. Save anyway if you plan to create it, otherwise pick one from the list.", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
        .formStyle(.grouped)
        .padding(.horizontal, 4)
    }

    // MARK: - SSID input

    @ViewBuilder
    private var ssidInput: some View {
        if knownSSIDs.isEmpty {
            HStack {
                TextField("", text: $ssid, prompt: Text("e.g. Home-Wifi-SSID"))
                    .textFieldStyle(.roundedBorder)
                helpButton { showHelpSSID.toggle() }
                    .popover(isPresented: $showHelpSSID, arrowEdge: .top) { ssidHelpPopover }
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Picker("", selection: ssidSelectionBinding) {
                        ForEach(knownSSIDs, id: \.self) { name in
                            HStack {
                                Text(name)
                                if name == currentConnected {
                                    Text("• connected")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .tag(name)
                        }
                        Divider()
                        Text("Custom SSID…").tag(Self.customTag)
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)

                    helpButton { showHelpSSID.toggle() }
                        .popover(isPresented: $showHelpSSID, arrowEdge: .top) { ssidHelpPopover }
                }

                if useCustomSSID {
                    HStack {
                        TextField("", text: $ssid, prompt: Text("Type the SSID exactly as it appears"))
                            .textFieldStyle(.roundedBorder)
                        Button {
                            useCustomSSID = false
                            ssid = knownSSIDs.first ?? ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                        .help("Go back to the known-network picker.")
                    }
                }
            }
        }
    }

    private var ssidSelectionBinding: Binding<String> {
        Binding(
            get: {
                if useCustomSSID { return Self.customTag }
                if knownSSIDs.contains(ssid) { return ssid }
                return knownSSIDs.first ?? Self.customTag
            },
            set: { newValue in
                if newValue == Self.customTag {
                    useCustomSSID = true
                    if knownSSIDs.contains(ssid) { ssid = "" }
                } else {
                    useCustomSSID = false
                    ssid = newValue
                }
            }
        )
    }

    private var currentConnected: String? {
        WiFiMonitor.currentSSID()
    }

    private var ssidHelpPopover: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Pick a Wi-Fi network you've joined before, or choose *Custom SSID…* to type a name for a network you haven't connected to yet.")
            Text("Match is case-insensitive and must be exact (no wildcards).")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.callout)
        .padding(10)
        .frame(width: 300)
    }

    // MARK: - Location input

    @ViewBuilder
    private var locationInput: some View {
        if model.availableLocations.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("No network locations are defined yet.")
                        .font(.callout)
                }
                Text("Create one in System Settings → Network → the popup menu next to 'Location' → Edit Locations. Then come back and reopen this window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.Network-Settings.extension") {
                            NSWorkspace.shared.open(url)
                        }
                    } label: {
                        Label("Open Network settings", systemImage: "arrow.up.forward.square")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        model.refreshAvailableLocations()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
        } else {
            HStack {
                Picker("", selection: $location) {
                    ForEach(pickerOptions, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                helpButton { showHelpLocation.toggle() }
                    .popover(isPresented: $showHelpLocation, arrowEdge: .top) {
                        Text("Pick the macOS network location to activate when this SSID is connected. Create or rename locations in System Settings → Network → (popup menu next to 'Location') → Edit Locations.")
                            .font(.callout)
                            .padding(10)
                            .frame(width: 300)
                    }
            }
        }
    }

    // MARK: - Footer

    private var footerBar: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { dismiss() }
                .keyboardShortcut(.cancelAction)
            Button(existing == nil ? "Add" : "Save") {
                commit()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!canSave)
        }
        .padding(12)
    }

    // MARK: - Logic

    private var canSave: Bool {
        !ssid.trimmingCharacters(in: .whitespaces).isEmpty
            && !location.isEmpty
            && !duplicateSSID
    }

    private var duplicateSSID: Bool {
        model.isDuplicateSSID(ssid, excluding: existing?.id)
    }

    private var pickerOptions: [String] {
        var names = model.availableLocations
        if !location.isEmpty, !names.contains(location) {
            names.insert(location, at: 0)
        }
        return names
    }

    private func commit() {
        let trimmedSSID = ssid.trimmingCharacters(in: .whitespaces)
        let rule = Rule(
            id: existing?.id ?? UUID(),
            ssid: trimmedSSID,
            location: location
        )
        model.upsertRule(rule)
    }

    private func helpButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "questionmark.circle")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.borderless)
    }
}
