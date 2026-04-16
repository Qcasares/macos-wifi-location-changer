import Foundation
import LocationChangerCore

enum ExitCode: Int32 {
    case ok = 0
    case configError = 1
    case permissionDenied = 2
    case switchFailed = 3
}

func main() -> Int32 {
    let log = LocationChangerLog.cli

    // Load config (creates default on first run).
    let store: ConfigStore
    let config: Config
    do {
        store = try ConfigStore.defaultStore()
        config = try store.load()
    } catch {
        log.error("config load failed: \(String(describing: error), privacy: .public)")
        return ExitCode.configError.rawValue
    }

    // Read current SSID.
    let ssid = WiFiMonitor.currentSSID()
    log.info("current SSID: \(ssid ?? "<nil>", privacy: .public)")

    if ssid == nil {
        // Could be disconnected OR could be a Location Services auth denial.
        // We still want to fall through to the fallback location.
        log.notice("no SSID; using fallback")
    }

    // Resolve target.
    let target = RuleEngine.resolve(ssid: ssid, in: config)
    log.info("target location: \(target, privacy: .public)")

    // Compare to current and switch if needed.
    let switcher = LocationSwitcher()
    let current: String
    do {
        current = try switcher.currentLocation()
    } catch {
        log.error("currentLocation failed: \(String(describing: error), privacy: .public)")
        return ExitCode.switchFailed.rawValue
    }

    if current == target {
        log.info("already at \(target, privacy: .public); no-op")
        return ExitCode.ok.rawValue
    }

    do {
        try switcher.switchTo(target)
    } catch {
        log.error("switchTo(\(target, privacy: .public)) failed: \(String(describing: error), privacy: .public)")
        return ExitCode.switchFailed.rawValue
    }
    log.info("switched to \(target, privacy: .public)")

    if config.notificationsEnabled {
        let notifier = Notifier()
        let sem = DispatchSemaphore(value: 0)
        Task {
            await notifier.notify(
                title: "Network Location Changed",
                body: "Switched to \(target)"
            )
            sem.signal()
        }
        // Allow up to 2s for the notification to be enqueued; otherwise the
        // process exits before UserNotifications finishes its work.
        _ = sem.wait(timeout: .now() + .seconds(2))
    }

    return ExitCode.ok.rawValue
}

exit(main())
