import Foundation

public enum RuleEngine {
    /// Resolve the target location for the given SSID.
    ///
    /// Matching is case-insensitive. An SSID of `nil` or empty string bypasses rule matching
    /// and returns the fallback. If no rule matches, returns the fallback location from config.
    public static func resolve(ssid: String?, in config: Config) -> String {
        guard let ssid, !ssid.isEmpty else {
            return config.fallback
        }

        let needle = ssid.lowercased()
        if let match = config.rules.first(where: { $0.ssid.lowercased() == needle }) {
            return match.location
        }
        return config.fallback
    }
}
