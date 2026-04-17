import SwiftUI
import LocationChangerCore

struct RuleEditorSheet: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.dismiss) private var dismiss

    /// nil → add mode. non-nil → edit the rule with this id.
    let existing: Rule?

    @State private var ssid: String
    @State private var location: String
    @State private var showHelpSSID = false
    @State private var showHelpLocation = false

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
        .frame(width: 460)
        .onAppear {
            if location.isEmpty, let first = model.availableLocations.first {
                location = first
            }
        }
    }

    private var headerBar: some View {
        HStack {
            Text(existing == nil ? "Add rule" : "Edit rule").font(.headline)
            Spacer()
        }
        .padding(12)
    }

    private var formBody: some View {
        Form {
            Section {
                HStack {
                    TextField("e.g. Home-Wifi-SSID", text: $ssid)
                        .textFieldStyle(.roundedBorder)
                    helpButton { showHelpSSID.toggle() }
                        .popover(isPresented: $showHelpSSID, arrowEdge: .top) {
                            Text("Enter the exact Wi-Fi network name. Match is case-insensitive. You can find the connected network name in the Wi-Fi menu (Wi-Fi icon in the menu bar).")
                                .font(.callout)
                                .padding(10)
                                .frame(width: 280)
                        }
                }
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
                HStack {
                    if model.availableLocations.isEmpty {
                        Text("No locations defined in System Settings yet.")
                            .foregroundStyle(.secondary)
                            .font(.callout)
                    } else {
                        Picker("", selection: $location) {
                            ForEach(pickerOptions, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }
                        .labelsHidden()
                    }
                    helpButton { showHelpLocation.toggle() }
                        .popover(isPresented: $showHelpLocation, arrowEdge: .top) {
                            Text("Pick the macOS network location to activate when this SSID is connected. Create or rename locations in System Settings → Network → (popup menu next to 'Location') → Edit Locations.")
                                .font(.callout)
                                .padding(10)
                                .frame(width: 300)
                        }
                }
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
