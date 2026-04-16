import Foundation
import SwiftUI
import ServiceManagement
import LocationChangerCore

@MainActor
final class AppModel: ObservableObject {
    @Published var config: Config
    @Published var currentSSID: String?
    @Published var currentLocation: String
    @Published var availableLocations: [String] = []
    @Published var lastSwitchAt: Date?
    @Published var errorMessage: String?
    @Published var validation: ConfigValidation = ConfigValidation(unknownRuleLocations: [], fallbackIsUnknown: false)

    private let store: ConfigStore
    private let switcher = LocationSwitcher()
    private let monitor = WiFiMonitor.shared
    private let notifier = Notifier()

    init() {
        let fallbackStore = ConfigStore(
            directoryURL: URL(fileURLWithPath: NSTemporaryDirectory()),
            fileURL: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("lc.json")
        )
        let resolvedStore = (try? ConfigStore.defaultStore()) ?? fallbackStore
        let resolvedConfig: Config
        do {
            resolvedConfig = try resolvedStore.load()
        } catch {
            LocationChangerLog.app.error("config load failed: \(String(describing: error), privacy: .public)")
            resolvedConfig = Config.default
        }
        self.store = resolvedStore
        self.config = resolvedConfig
        self.currentLocation = (try? switcher.currentLocation()) ?? "?"
    }

    func bootstrap() {
        refreshAvailableLocations()
        monitor.requestAuthorization()
        Task { await notifier.requestAuthorization() }
        do {
            try monitor.start { [weak self] ssid in
                Task { @MainActor in
                    self?.handleSSIDChange(ssid)
                }
            }
        } catch {
            LocationChangerLog.app.error("monitor start failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Wi-Fi monitor failed to start: \(error)"
        }
    }

    private func handleSSIDChange(_ ssid: String?) {
        currentSSID = ssid
        let target = RuleEngine.resolve(ssid: ssid, in: config)
        applyLocation(target, trigger: "ssid=\(ssid ?? "<nil>")")
    }

    func switchNow() {
        let target = RuleEngine.resolve(ssid: currentSSID, in: config)
        applyLocation(target, trigger: "manual")
    }

    private func applyLocation(_ target: String, trigger: String) {
        do {
            let current = try switcher.currentLocation()
            currentLocation = current
            if current == target {
                LocationChangerLog.app.info("already at \(target, privacy: .public); no-op (\(trigger, privacy: .public))")
                return
            }
            try switcher.switchTo(target)
            currentLocation = target
            lastSwitchAt = Date()
            LocationChangerLog.app.info("switched to \(target, privacy: .public) (\(trigger, privacy: .public))")
            if config.notificationsEnabled {
                notifier.notifyFireAndForget(
                    title: "Network Location Changed",
                    body: "Switched to \(target)"
                )
            }
            errorMessage = nil
        } catch {
            LocationChangerLog.app.error("switch failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Switch failed: \(error)"
        }
    }

    func refreshAvailableLocations() {
        do {
            availableLocations = try switcher.availableLocations()
        } catch {
            LocationChangerLog.app.error("availableLocations failed: \(String(describing: error), privacy: .public)")
            availableLocations = []
        }
        refreshValidation()
    }

    private func refreshValidation() {
        let v = RuleEngine.validate(config, against: availableLocations)
        validation = v
        for rule in v.unknownRuleLocations {
            LocationChangerLog.app.notice("rule SSID=\(rule.ssid, privacy: .public) → unknown location \(rule.location, privacy: .public)")
        }
        if v.fallbackIsUnknown {
            LocationChangerLog.app.notice("fallback \(self.config.fallback, privacy: .public) is not a defined location")
        }
    }

    // MARK: - Config mutation

    func addRule(ssid: String, location: String) {
        guard !ssid.isEmpty, !location.isEmpty else { return }
        config.rules.append(Rule(ssid: ssid, location: location))
        saveConfig()
    }

    func removeRules(at offsets: IndexSet) {
        config.rules.remove(atOffsets: offsets)
        saveConfig()
    }

    func updateRule(id: UUID, ssid: String? = nil, location: String? = nil) {
        guard let i = config.rules.firstIndex(where: { $0.id == id }) else { return }
        if let ssid { config.rules[i].ssid = ssid }
        if let location { config.rules[i].location = location }
        saveConfig()
    }

    func setFallback(_ name: String) {
        config.fallback = name
        saveConfig()
    }

    func setNotificationsEnabled(_ enabled: Bool) {
        config.notificationsEnabled = enabled
        saveConfig()
    }

    private func saveConfig() {
        do {
            try store.save(config)
        } catch {
            LocationChangerLog.app.error("config save failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Config save failed: \(error)"
        }
        refreshValidation()
    }

    var configFileURL: URL { store.fileURL }

    // MARK: - Login item (SMAppService)

    var launchAtLoginEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            objectWillChange.send()
        } catch {
            LocationChangerLog.app.error("SMAppService toggle failed: \(String(describing: error), privacy: .public)")
            errorMessage = "Launch-at-login toggle failed: \(error)"
        }
    }
}
