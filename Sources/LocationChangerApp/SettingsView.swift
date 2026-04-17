import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var model: AppModel

    enum Tab: Hashable { case general, rules, advanced, help }
    @State private var selected: Tab = .rules

    var body: some View {
        TabView(selection: $selected) {
            GeneralTabView()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(Tab.general)

            RulesTabView(openHelp: { selected = .help })
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle") }
                .tag(Tab.rules)

            AdvancedTabView()
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
                .tag(Tab.advanced)

            HelpTabView()
                .tabItem { Label("Help", systemImage: "questionmark.circle") }
                .tag(Tab.help)
        }
        .environmentObject(model)
        .frame(minWidth: 560, idealWidth: 620, minHeight: 440, idealHeight: 520)
        .onAppear { model.refreshAvailableLocations() }
    }
}
