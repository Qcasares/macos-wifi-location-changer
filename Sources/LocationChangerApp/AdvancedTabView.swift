import SwiftUI
import AppKit

struct AdvancedTabView: View {
    @EnvironmentObject var model: AppModel
    @State private var copiedLogCommand = false

    private let logCommand = #"log stream --predicate 'subsystem == "com.locationchanger"' --level info"#

    var body: some View {
        Form {
            Section("Network locations") {
                HStack {
                    Text("\(model.availableLocations.count) defined")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Refresh") {
                        model.refreshAvailableLocations()
                    }
                }
                Text("Locations refresh automatically when this window regains focus.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Files") {
                Button {
                    NSWorkspace.shared.activateFileViewerSelecting([model.configFileURL])
                } label: {
                    Label("Reveal config.json in Finder", systemImage: "folder")
                }

                Button {
                    let logsURL = URL(fileURLWithPath: NSHomeDirectory())
                        .appendingPathComponent("Library/Logs", isDirectory: true)
                    NSWorkspace.shared.open(logsURL)
                } label: {
                    Label("Open ~/Library/Logs", systemImage: "doc.text.magnifyingglass")
                }
            }

            Section("Streaming logs") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Run this in Terminal to tail the app's log stream in real time:")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack {
                        Text(logCommand)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(6)
                            .background(.quaternary, in: .rect(cornerRadius: 5))
                        Spacer()
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(logCommand, forType: .string)
                            copiedLogCommand = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                copiedLogCommand = false
                            }
                        } label: {
                            Image(systemName: copiedLogCommand ? "checkmark" : "doc.on.doc")
                        }
                        .buttonStyle(.borderless)
                        .help("Copy command")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
