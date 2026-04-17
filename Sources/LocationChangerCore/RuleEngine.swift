import Foundation

public struct ConfigValidation: Sendable, Hashable {
    public let unknownRuleLocations: [Rule]
    public let fallbackIsUnknown: Bool

    public init(unknownRuleLocations: [Rule], fallbackIsUnknown: Bool) {
        self.unknownRuleLocations = unknownRuleLocations
        self.fallbackIsUnknown = fallbackIsUnknown
    }

    public var isClean: Bool { unknownRuleLocations.isEmpty && !fallbackIsUnknown }
}

public enum FallbackReason: Sendable, Hashable {
    /// SSID was nil or empty (disconnected or auth denied).
    case noSSID
    /// An SSID was present but no rule matched it.
    case noRuleMatched
}

public enum Resolution: Sendable, Hashable {
    case matched(Rule)
    case fallback(FallbackReason)

    public var targetLocation: String? {
        if case .matched(let rule) = self { return rule.location }
        return nil
    }
}

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

    /// Like `resolve`, but preserves the rule that matched (or the reason no rule did).
    /// Used by UI surfaces that want to display "matched: <rule name>" vs a fallback.
    public static func explain(ssid: String?, in config: Config) -> Resolution {
        guard let ssid, !ssid.isEmpty else {
            return .fallback(.noSSID)
        }
        let needle = ssid.lowercased()
        if let match = config.rules.first(where: { $0.ssid.lowercased() == needle }) {
            return .matched(match)
        }
        return .fallback(.noRuleMatched)
    }

    /// Check every rule's target location (and the fallback) against the set of
    /// locations actually defined in the system. Lets callers surface stale
    /// rules at startup rather than at switch time.
    public static func validate(_ config: Config, against definedLocations: [String]) -> ConfigValidation {
        let known = Set(definedLocations)
        let unknownRules = config.rules.filter { !known.contains($0.location) }
        return ConfigValidation(
            unknownRuleLocations: unknownRules,
            fallbackIsUnknown: !known.contains(config.fallback)
        )
    }
}
