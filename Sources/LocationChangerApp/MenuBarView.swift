import SwiftUI
import AppKit

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header
            Divider()
            statusRows
            Divider()
            actions
            Divider()
            footer
        }
        .padding(12)
        .frame(minWidth: 280)
    }

    private var header: some View {
        HStack {
            Image(systemName: "wifi.square.fill")
                .foregroundStyle(.tint)
                .font(.title3)
            Text("LocationChanger").font(.headline)
        }
    }

    private var statusRows: some View {
        VStack(alignment: .leading, spacing: 4) {
            labeledRow("SSID", value: model.currentSSID ?? "—")
            labeledRow("Location", value: model.currentLocation)
            if let at = model.lastSwitchAt {
                labeledRow("Last switch", value: Self.relativeFormatter.localizedString(for: at, relativeTo: Date()))
            }
            if let err = model.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    private func labeledRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.callout)
    }

    private var actions: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Switch now") { model.switchNow() }
                .buttonStyle(.plain)
            Button("Settings…") {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            }
            .buttonStyle(.plain)
        }
    }

    private var footer: some View {
        Button("Quit LocationChanger") {
            NSApp.terminate(nil)
        }
        .buttonStyle(.plain)
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
