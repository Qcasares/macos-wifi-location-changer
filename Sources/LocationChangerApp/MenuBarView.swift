import SwiftUI
import AppKit
import CoreLocation
import LocationChangerCore

struct MenuBarView: View {
    @EnvironmentObject var model: AppModel
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if !model.validation.isClean {
                validationStrip
            }
            if model.config.rules.isEmpty {
                firstRunHint
            }
            statusCard
            Divider()
            actionRow
            Divider()
            footerRow
        }
        .padding(14)
        .frame(width: 320)
    }

    private var firstRunHint: some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Add your first rule")
                        .font(.callout.weight(.medium))
                    Text("Open Settings → Rules to map an SSID to a location.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(Color.accentColor.opacity(0.10), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: statusSymbolName)
                .foregroundStyle(statusSymbolTint)
                .font(.title3)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 0) {
                Text("LocationChanger").font(.headline)
                Text(statusHeadline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var statusSymbolName: String {
        switch statusKind {
        case .matched: return "checkmark.circle.fill"
        case .connectedNoMatch: return "wifi"
        case .disconnected: return "wifi.slash"
        case .noAuth: return "wifi.exclamationmark"
        }
    }

    private var statusSymbolTint: Color {
        switch statusKind {
        case .matched: return .green
        case .connectedNoMatch: return .secondary
        case .disconnected: return .secondary
        case .noAuth: return .orange
        }
    }

    private var statusHeadline: String {
        switch statusKind {
        case .matched(let rule): return "Matched: \(rule.ssid)"
        case .connectedNoMatch: return "Connected — no rule matched"
        case .disconnected: return "Disconnected or SSID hidden"
        case .noAuth: return "Location Services needed"
        }
    }

    private enum StatusKind {
        case matched(Rule)
        case connectedNoMatch
        case disconnected
        case noAuth
    }

    private var statusKind: StatusKind {
        if model.authorizationStatus == .denied || model.authorizationStatus == .restricted {
            return .noAuth
        }
        switch model.resolution {
        case .matched(let rule): return .matched(rule)
        case .fallback(.noSSID): return model.authorizationStatus == .notDetermined ? .noAuth : .disconnected
        case .fallback(.noRuleMatched): return .connectedNoMatch
        }
    }

    // Convenience overload to let the switch bind a local Rule.
    private struct LocalMatch { let rule: Rule }

    // MARK: - Validation strip

    private var validationStrip: some View {
        Button {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("\(validationSummary) — review in Settings")
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(.orange.opacity(0.12), in: .rect(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var validationSummary: String {
        var parts: [String] = []
        if !model.validation.unknownRuleLocations.isEmpty {
            parts.append("\(model.validation.unknownRuleLocations.count) rule\(model.validation.unknownRuleLocations.count == 1 ? "" : "s") with missing location")
        }
        if model.validation.fallbackIsUnknown {
            parts.append("fallback is unknown")
        }
        return parts.joined(separator: ", ")
    }

    // MARK: - Status card

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            detailRow("SSID", value: model.currentSSID ?? "—")
            detailRow("Location", value: model.currentLocation)
            if let rule = model.matchedRule {
                detailRow("Active rule", value: "\(rule.ssid) → \(rule.location)", emphasise: true)
            } else {
                detailRow("Fallback", value: model.config.fallback)
            }
            if let at = model.lastSwitchAt {
                detailRow("Last switch", value: Self.relativeFormatter.localizedString(for: at, relativeTo: Date()))
            }
            if let err = model.errorMessage {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(3)
            }
        }
    }

    private func detailRow(_ label: String, value: String, emphasise: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 96, alignment: .leading)
            Text(value)
                .fontWeight(emphasise ? .semibold : .regular)
                .foregroundStyle(emphasise ? .primary : .primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                model.switchNow()
            } label: {
                Label("Switch now", systemImage: "arrow.triangle.2.circlepath")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.regular)
            Button {
                NSApp.activate(ignoringOtherApps: true)
                openSettings()
            } label: {
                Label("Settings…", systemImage: "gearshape")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.bordered)
    }

    private var footerRow: some View {
        HStack {
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
        }
    }

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        return f
    }()
}
