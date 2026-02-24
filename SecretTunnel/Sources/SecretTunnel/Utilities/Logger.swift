import OSLog

struct Log {
    static let instance = Logger(subsystem: Constants.bundleIdentifier, category: "instance")
    static let tunnel = Logger(subsystem: Constants.bundleIdentifier, category: "tunnel")
    static let api = Logger(subsystem: Constants.bundleIdentifier, category: "api")
    static let ui = Logger(subsystem: Constants.bundleIdentifier, category: "ui")
    static let keychain = Logger(subsystem: Constants.bundleIdentifier, category: "keychain")
    static let connection = Logger(subsystem: Constants.bundleIdentifier, category: "connection")
}
