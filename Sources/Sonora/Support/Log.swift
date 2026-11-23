import OSLog

enum Log {
    private static let subsystem = "dev.local.sonora"

    static let app = Logger(subsystem: subsystem, category: "app")
    static let audio = Logger(subsystem: subsystem, category: "audio")
    static let speech = Logger(subsystem: subsystem, category: "speech")
    static let input = Logger(subsystem: subsystem, category: "input")
    static let history = Logger(subsystem: subsystem, category: "history")
}
