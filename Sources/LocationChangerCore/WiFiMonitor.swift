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
public final class WiFiMonitor: NSObject, @preconcurrency CWEventDelegate {
    public static let shared = WiFiMonitor()

    private let client = CWWiFiClient.shared()
    private var handler: ((String?) -> Void)?
    private let locationDelegate = LocationAuthDelegate()
    private let locationManager = CLLocationManager()

    public override init() {
        super.init()
        locationManager.delegate = locationDelegate
    }

    /// One-shot: returns the SSID of the default Wi-Fi interface, or nil
    /// if no interface exists or authorization is denied.
    public nonisolated static func currentSSID() -> String? {
        guard let iface = CWWiFiClient.shared().interface() else { return nil }
        return iface.ssid()
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

    public func ssidDidChangeForWiFiInterface(withName interfaceName: String) {
        let ssid = client.interface(withName: interfaceName)?.ssid()
        LocationChangerLog.wifi.info("ssidDidChange: \(ssid ?? "<nil>", privacy: .public)")
        handler?(ssid)
    }

    public func linkDidChangeForWiFiInterface(withName interfaceName: String) {
        let ssid = client.interface(withName: interfaceName)?.ssid()
        LocationChangerLog.wifi.info("linkDidChange ssid=\(ssid ?? "<nil>", privacy: .public)")
        handler?(ssid)
    }
}

/// Minimal CLLocationManagerDelegate so the system prompt doesn't cause a warning.
private final class LocationAuthDelegate: NSObject, CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        LocationChangerLog.wifi.info("location auth status: \(manager.authorizationStatus.rawValue)")
    }
}
