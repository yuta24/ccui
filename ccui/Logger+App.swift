import OSLog

extension Logger {
    nonisolated private static let subsystem = Bundle.main.bundleIdentifier ?? "com.bivre.ccui"

    nonisolated static let store = Logger(subsystem: subsystem, category: "Store")
    nonisolated static let persistence = Logger(subsystem: subsystem, category: "Persistence")
    nonisolated static let services = Logger(subsystem: subsystem, category: "Services")
    nonisolated static let terminal = Logger(subsystem: subsystem, category: "Terminal")
}
