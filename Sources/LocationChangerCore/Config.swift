import Foundation

public struct Rule: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var ssid: String
    public var location: String

    public init(id: UUID = UUID(), ssid: String, location: String) {
        self.id = id
        self.ssid = ssid
        self.location = location
    }
}

public struct Config: Codable, Hashable, Sendable {
    public var fallback: String
    public var notificationsEnabled: Bool
    public var rules: [Rule]

    public init(
        fallback: String = "Automatic",
        notificationsEnabled: Bool = true,
        rules: [Rule] = []
    ) {
        self.fallback = fallback
        self.notificationsEnabled = notificationsEnabled
        self.rules = rules
    }

    public static let `default` = Config()
}

public enum ConfigError: Error, Equatable {
    case directoryUnavailable
    case decodeFailed(String)
    case encodeFailed(String)
    case writeFailed(String)
}

public struct ConfigStore {
    public let directoryURL: URL
    public let fileURL: URL

    /// Default location: ~/Library/Application Support/LocationChanger/config.json
    public static func defaultStore() throws -> ConfigStore {
        let fm = FileManager.default
        guard let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw ConfigError.directoryUnavailable
        }
        let dir = support.appendingPathComponent("LocationChanger", isDirectory: true)
        let file = dir.appendingPathComponent("config.json", isDirectory: false)
        return ConfigStore(directoryURL: dir, fileURL: file)
    }

    public init(directoryURL: URL, fileURL: URL) {
        self.directoryURL = directoryURL
        self.fileURL = fileURL
    }

    /// Load the config, creating a default file on first run.
    public func load() throws -> Config {
        let fm = FileManager.default

        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        if !fm.fileExists(atPath: fileURL.path) {
            let def = Config.default
            try save(def)
            return def
        }

        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            throw ConfigError.decodeFailed("could not read \(fileURL.path): \(error.localizedDescription)")
        }
        do {
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            throw ConfigError.decodeFailed(error.localizedDescription)
        }
    }

    /// Atomic save: write to a sibling temp file, then rename.
    public func save(_ config: Config) throws {
        let fm = FileManager.default
        if !fm.fileExists(atPath: directoryURL.path) {
            try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data: Data
        do {
            data = try encoder.encode(config)
        } catch {
            throw ConfigError.encodeFailed(error.localizedDescription)
        }

        do {
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            throw ConfigError.writeFailed(error.localizedDescription)
        }
    }
}
