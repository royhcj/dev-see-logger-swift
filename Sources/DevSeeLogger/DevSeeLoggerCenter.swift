import Foundation

public enum DevSeeLoggerCenter {
    public static let defaultServerURL = URL(string: "http://127.0.0.1:9090")!

    private static let stateLock = NSLock()
    nonisolated(unsafe) private static var sharedLogger: DevSeeLogger?
    nonisolated(unsafe) private static var sharedConfiguration: DevSeeLoggerConfiguration?

    public static func configure(_ configuration: DevSeeLoggerConfiguration) {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let sharedConfiguration, sharedConfiguration == configuration, sharedLogger != nil {
            return
        }

        sharedConfiguration = configuration
        sharedLogger = DevSeeLogger(configuration: configuration)
    }

    public static var shared: DevSeeLogger {
        stateLock.lock()
        defer { stateLock.unlock() }

        if let sharedLogger {
            return sharedLogger
        }

        let configuration = defaultConfiguration()
        let logger = DevSeeLogger(configuration: configuration)
        sharedConfiguration = configuration
        sharedLogger = logger
        return logger
    }

    @discardableResult
    public static func handleURL(_ url: URL) -> Bool {
        let result = shared.handleURL(url)
        switch result {
        case .ignored:
            return false
        case .connected, .failed:
            return true
        }
    }

    static func resetForTesting() {
        stateLock.lock()
        sharedConfiguration = nil
        sharedLogger = nil
        stateLock.unlock()
    }

    private static func defaultConfiguration() -> DevSeeLoggerConfiguration {
        DevSeeLoggerConfiguration(
            appId: Bundle.main.bundleIdentifier ?? "dev.see.app",
            serverURL: defaultServerURL
        )
    }
}
