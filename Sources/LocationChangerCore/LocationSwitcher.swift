import Foundation
import SystemConfiguration

public enum SwitcherError: Error, CustomStringConvertible {
    case noCurrentSet
    case notFound(String)
    case commitFailed(String)
    case processFailed(Int32, String)

    public var description: String {
        switch self {
        case .noCurrentSet: return "no current network set"
        case .notFound(let n): return "network location not found: \(n)"
        case .commitFailed(let m): return "SCPreferencesCommitChanges failed: \(m)"
        case .processFailed(let c, let o): return "scselect exited \(c): \(o)"
        }
    }
}

public struct LocationSwitcher {
    public init() {}

    /// Name of the currently active network set.
    ///
    /// Reads via SystemConfiguration (no authorization required). Falls back to parsing
    /// `scselect` output if the SC path yields nothing.
    public func currentLocation() throws -> String {
        if let name = try scReadCurrentName() {
            return name
        }
        return try scselectParseCurrent()
    }

    /// All defined network-set names.
    public func availableLocations() throws -> [String] {
        if let names = try scReadAllNames(), !names.isEmpty {
            return names
        }
        return try scselectParseAll()
    }

    /// Switch to a named location. Tries the SystemConfiguration write path first;
    /// on any failure, falls back to `/usr/sbin/scselect`.
    public func switchTo(_ name: String) throws {
        LocationChangerLog.switcher.info("switchTo \(name, privacy: .public)")
        do {
            try scCommitSwitch(to: name)
            return
        } catch {
            LocationChangerLog.switcher.notice(
                "SC commit path failed (\(String(describing: error), privacy: .public)); falling back to scselect"
            )
        }
        try runScselect(name)
    }

    // MARK: - SystemConfiguration read

    private func scReadAllNames() throws -> [String]? {
        guard let prefs = SCPreferencesCreate(nil, "LocationChanger" as CFString, nil) else {
            return nil
        }
        guard let setsCF = SCNetworkSetCopyAll(prefs) else { return nil }
        let sets = setsCF as! [SCNetworkSet]
        return sets.compactMap { SCNetworkSetGetName($0) as String? }
    }

    private func scReadCurrentName() throws -> String? {
        guard let prefs = SCPreferencesCreate(nil, "LocationChanger" as CFString, nil) else {
            return nil
        }
        guard let current = SCNetworkSetCopyCurrent(prefs) else { return nil }
        return SCNetworkSetGetName(current) as String?
    }

    // MARK: - SystemConfiguration write

    private func scCommitSwitch(to name: String) throws {
        guard let prefs = SCPreferencesCreate(nil, "LocationChanger" as CFString, nil) else {
            throw SwitcherError.commitFailed("SCPreferencesCreate returned nil")
        }
        guard let setsCF = SCNetworkSetCopyAll(prefs) else {
            throw SwitcherError.commitFailed("SCNetworkSetCopyAll returned nil")
        }
        let sets = setsCF as! [SCNetworkSet]
        guard let target = sets.first(where: { (SCNetworkSetGetName($0) as String?) == name }) else {
            throw SwitcherError.notFound(name)
        }
        guard SCNetworkSetSetCurrent(target) else {
            throw SwitcherError.commitFailed("SCNetworkSetSetCurrent returned false")
        }
        guard SCPreferencesCommitChanges(prefs) else {
            throw SwitcherError.commitFailed("SCPreferencesCommitChanges returned false")
        }
        guard SCPreferencesApplyChanges(prefs) else {
            throw SwitcherError.commitFailed("SCPreferencesApplyChanges returned false")
        }
    }

    // MARK: - scselect fallback

    private func scselectParseCurrent() throws -> String {
        let out = try runScselectList()
        for line in out.split(whereSeparator: { $0 == "\n" }) {
            let s = String(line)
            guard s.contains("* ") else { continue }
            if let name = extractParenthesised(s) { return name }
        }
        throw SwitcherError.noCurrentSet
    }

    private func scselectParseAll() throws -> [String] {
        let out = try runScselectList()
        var names: [String] = []
        for line in out.split(whereSeparator: { $0 == "\n" }) {
            if let n = extractParenthesised(String(line)) {
                names.append(n)
            }
        }
        return names
    }

    private func extractParenthesised(_ s: String) -> String? {
        guard let start = s.lastIndex(of: "("),
              let end = s.lastIndex(of: ")"),
              start < end else { return nil }
        return String(s[s.index(after: start)..<end])
    }

    private func runScselectList() throws -> String {
        try runProcess("/usr/sbin/scselect", [])
    }

    private func runScselect(_ name: String) throws {
        _ = try runProcess("/usr/sbin/scselect", [name])
    }

    private func runProcess(_ launchPath: String, _ args: [String]) throws -> String {
        let proc = Process()
        proc.launchPath = launchPath
        proc.arguments = args
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = pipe
        try proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let out = String(data: data, encoding: .utf8) ?? ""
        if proc.terminationStatus != 0 {
            throw SwitcherError.processFailed(proc.terminationStatus, out)
        }
        return out
    }
}
