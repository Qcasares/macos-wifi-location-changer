import SwiftUI
import LocationChangerCore

struct RulesTabView: View {
    @EnvironmentObject var model: AppModel
    var openHelp: () -> Void

    @State private var editingRule: Rule?
    @State private var showingAdd: Bool = false
    @State private var ruleToDelete: Rule?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if model.config.rules.isEmpty {
                emptyState
            } else {
                rulesList
            }
            Divider()
            toolbar
        }
        .sheet(isPresented: $showingAdd) {
            RuleEditorSheet(existing: nil)
                .environmentObject(model)
        }
        .sheet(item: $editingRule) { rule in
            RuleEditorSheet(existing: rule)
                .environmentObject(model)
        }
        .confirmationDialog(
            "Delete this rule?",
            isPresented: .init(
                get: { ruleToDelete != nil },
                set: { if !$0 { ruleToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: ruleToDelete
        ) { rule in
            Button("Delete", role: .destructive) {
                model.removeRule(id: rule.id)
                ruleToDelete = nil
            }
            Button("Cancel", role: .cancel) { ruleToDelete = nil }
        } message: { rule in
            Text("SSID '\(rule.ssid)' → \(rule.location)")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SSID → Location rules")
                    .font(.headline)
                Text("Rules are evaluated top-to-bottom. First match wins.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                openHelp()
            } label: {
                Image(systemName: "questionmark.circle")
            }
            .buttonStyle(.borderless)
            .help("Open the Help tab to learn how rules work.")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "mappin.and.ellipse")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.secondary)
            Text("No rules yet")
                .font(.title3.bold())
            Text("Add a rule to switch your macOS network location automatically when you join a specific Wi-Fi network. If no rule matches, the fallback in General is used.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 380)
            Button {
                showingAdd = true
            } label: {
                Label("Add your first rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            Button("Learn how rules work", action: openHelp)
                .buttonStyle(.link)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Rules list

    private var rulesList: some View {
        List {
            columnHeader
            ForEach(model.config.rules) { rule in
                RuleRow(
                    rule: rule,
                    isMatched: model.matchedRule?.id == rule.id,
                    isDuplicate: model.isDuplicateSSID(rule.ssid, excluding: rule.id),
                    locationUnknown: model.isRuleLocationUnknown(rule),
                    onEdit: { editingRule = rule },
                    onDelete: { ruleToDelete = rule }
                )
                .contentShape(Rectangle())
                .onTapGesture(count: 2) { editingRule = rule }
            }
            .onMove(perform: model.moveRules)
        }
        .listStyle(.inset)
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            Text("")
                .frame(width: 16, alignment: .leading)
            Text("SSID")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("Target location")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
            Color.clear.frame(width: 72)
        }
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack {
            Button {
                showingAdd = true
            } label: {
                Label("Add rule", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)

            Spacer()

            if !model.config.rules.isEmpty {
                Text("\(model.config.rules.count) rule\(model.config.rules.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
    }
}

private struct RuleRow: View {
    let rule: Rule
    let isMatched: Bool
    let isDuplicate: Bool
    let locationUnknown: Bool
    var onEdit: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            statusDot
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.ssid)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if isDuplicate {
                    Text("duplicate SSID")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.location)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if locationUnknown {
                    Text("not in System Settings")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 4) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                .help("Edit rule")
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete rule")
            }
            .frame(width: 72, alignment: .trailing)
        }
        .padding(.vertical, 4)
    }

    private var statusDot: some View {
        ZStack {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
        .help(dotHelp)
    }

    private var dotColor: Color {
        if isDuplicate { return .red }
        if locationUnknown { return .orange }
        if isMatched { return .green }
        return .secondary.opacity(0.5)
    }

    private var dotHelp: String {
        if isDuplicate { return "Duplicate — first match wins so this rule is unreachable." }
        if locationUnknown { return "Target location is not defined in System Settings." }
        if isMatched { return "This rule matches your current SSID right now." }
        return "Inactive — will match when you join this SSID."
    }
}
