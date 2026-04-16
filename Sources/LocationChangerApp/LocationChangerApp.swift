import SwiftUI
import ServiceManagement
import AppKit
import LocationChangerCore

@main
struct LocationChangerApp: App {
    @StateObject private var model = AppModel()

    init() {
        LocationChangerLog.app.info("LocationChangerApp launching")
        if CommandLine.arguments.contains("--unregister-login-item") {
            LocationChangerLog.app.info("--unregister-login-item flag: unregistering and quitting")
            try? SMAppService.mainApp.unregister()
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    var body: some Scene {
        MenuBarExtra("LocationChanger", systemImage: "wifi.square") {
            MenuBarView()
                .environmentObject(model)
                .task { model.bootstrap() }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(minWidth: 520, minHeight: 420)
        }
    }
}
