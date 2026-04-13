import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bivre.ccui"

    static let store = Logger(subsystem: subsystem, category: "Store")
    static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    static let services = Logger(subsystem: subsystem, category: "Services")
}
