import Foundation
import OSLog

public enum LocationChangerLog {
    public static let subsystem = "com.locationchanger"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let cli = Logger(subsystem: subsystem, category: "cli")
    public static let wifi = Logger(subsystem: subsystem, category: "wifi")
    public static let switcher = Logger(subsystem: subsystem, category: "switcher")
    public static let config = Logger(subsystem: subsystem, category: "config")
    public static let notifier = Logger(subsystem: subsystem, category: "notifier")
}
