import Foundation
import CoreWLAN
import CoreLocation

public enum WiFiError: Error, CustomStringConvertible {
    case noInterface
    case authorizationDenied
    case monitoringFailed(String)

    public var description: String {
        switch self {
        case .noInterface: return "no Wi-Fi interface available"
        case .authorizationDenied: return "location authorization denied; SSID cannot be read on macOS 14+"
        case .monitoringFailed(let m): return "failed to start Wi-Fi monitoring: \(m)"
        }
    }
}

/// Wraps CWWiFiClient and CLLocationManager. Two entry points:
///
/// - `currentSSID()` — one-shot synchronous read, used by the CLI.
/// - `start(_:)` — subscribes to live SSID changes via CWEventDelegate,
///   used by the menubar app.
///
/// On macOS 14+ the SSID read requires Location Services authorization;
/// callers that need live SSIDs must have requested it.
@MainActor
public final class WiFiMonitor: NSObject, CWEventDelegate, CLLocationManagerDelegate {
    public static let shared = WiFiMonitor()

    private let client = CWWiFiClient.shared()
    private var handler: ((String?) -> Void)?
    private let locationManager = CLLocationManager()

    /// Fires on every `locationManagerDidChangeAuthorization` callback so UI
    /// can re-render when the user grants/denies/changes the permission
    /// (including returning from System Settings).
    public var onAuthorizationChange: (() -> Void)?

    public override init() {
        super.init()
        locationManager.delegate = self
    }

    /// One-shot: returns the SSID of the default Wi-Fi interface, or nil
    /// if no interface exists or authorization is denied.
    public nonisolated static func currentSSID() -> String? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }
        return iface.ssid()
    }

    /// Saved Wi-Fi network profiles in preferred-order. Populates rule-editor
    /// pickers so the user doesn't have to type SSIDs by hand. Returns an
    /// empty array if the interface or configuration isn't available.
    public nonisolated static func knownSSIDs() -> [String] {
        guard let iface = CWWiFiClient.shared().interface() else { return [] }
        let profiles = iface.configuration()?.networkProfiles
        let list = profiles?.array as? [CWNetworkProfile] ?? []
        var seen = Set<String>()
        var out: [String] = []
        for profile in list {
            if let ssid = profile.ssid, !ssid.isEmpty, seen.insert(ssid).inserted {
                out.append(ssid)
            }
        }
        return out
    }

    /// Current authorization status for the Location Services prompt that
    /// unlocks SSID reads on macOS 14+.
    public var authorizationStatus: CLAuthorizationStatus {
        locationManager.authorizationStatus
    }

    /// Present the system prompt (or no-op if already answered).
    public func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    /// Begin monitoring SSID changes. The handler fires on each change.
    /// Safe to call once per process.
    public func start(_ handler: @escaping (String?) -> Void) throws {
        self.handler = handler
        client.delegate = self
        do {
            try client.startMonitoringEvent(with: .ssidDidChange)
            try client.startMonitoringEvent(with: .linkDidChange)
        } catch {
            throw WiFiError.monitoringFailed(error.localizedDescription)
        }
        // Emit an initial value so the UI reflects current state immediately.
        handler(Self.currentSSID())
        LocationChangerLog.wifi.info("WiFiMonitor started")
    }

    public func stop() {
        try? client.stopMonitoringAllEvents()
        client.delegate = nil
        handler = nil
        LocationChangerLog.wifi.info("WiFiMonitor stopped")
    }

    // MARK: - CWEventDelegate
    //
    // CoreWLAN delivers these callbacks on a background dispatch queue
    // (com.apple.wifi.xpcclient.event.*). The methods must be `nonisolated`
    // so they don't attempt to assert MainActor on that queue — the runtime
    // check fires otherwise and the process traps with EXC_BREAKPOINT.
    // We hop to MainActor explicitly for any isolated state access.

    public nonisolated func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        let ssid = CWWiFiClient.shared().interface(withName: interfaceName)?.ssid()
        LocationChangerLog.wifi.info("ssidDidChange: \(ssid ?? "<nil>", privacy: .public)")
        Task { @MainActor [weak self] in
            self?.handler?(ssid)
        }
    }

    public nonisolated func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        let ssid = CWWiFiClient.shared().interface(withName: interfaceName)?.ssid()
        LocationChangerLog.wifi.info("linkDidChange ssid=\(ssid ?? "<nil>", privacy: .public)")
        Task { @MainActor [weak self] in
            self?.handler?(ssid)
        }
    }

    // MARK: - CLLocationManagerDelegate
    //
    // Same isolation rule applies — CLLocationManager dispatches on its own
    // queue on macOS.

    public nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        LocationChangerLog.wifi.info("location auth status: \(status.rawValue)")
        Task { @MainActor [weak self] in
            self?.onAuthorizationChange?()
        }
    }
}
