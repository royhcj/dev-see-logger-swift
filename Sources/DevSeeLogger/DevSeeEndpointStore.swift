import Foundation

protocol DevSeeEndpointStoring: Sendable {
    func loadEndpoint() -> DevSeeEndpoint?
    func saveEndpoint(_ endpoint: DevSeeEndpoint)
    func clearEndpoint()
}

struct DevSeeNoopEndpointStore: DevSeeEndpointStoring {
    func loadEndpoint() -> DevSeeEndpoint? {
        nil
    }

    func saveEndpoint(_ endpoint: DevSeeEndpoint) {}

    func clearEndpoint() {}
}

final class DevSeeUserDefaultsEndpointStore: @unchecked Sendable, DevSeeEndpointStoring {
    private enum Key {
        static let prefix = "devsee.logger.endpoint"
        static let host = "host"
        static let port = "port"
    }

    private let defaults: UserDefaults
    private let hostKey: String
    private let portKey: String

    init(appId: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let scope = appId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "default"
            : appId
        let namespacedPrefix = "\(Key.prefix).\(scope)"
        self.hostKey = "\(namespacedPrefix).\(Key.host)"
        self.portKey = "\(namespacedPrefix).\(Key.port)"
    }

    func loadEndpoint() -> DevSeeEndpoint? {
        guard let host = defaults.string(forKey: hostKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !host.isEmpty else {
            return nil
        }

        guard let storedPort = readStoredPort() else {
            clearEndpoint()
            return nil
        }

        guard (1...65_535).contains(storedPort) else {
            clearEndpoint()
            return nil
        }

        return DevSeeEndpoint(scheme: "http", host: host, port: storedPort)
    }

    func saveEndpoint(_ endpoint: DevSeeEndpoint) {
        defaults.set(endpoint.host, forKey: hostKey)
        defaults.set(endpoint.port, forKey: portKey)
    }

    func clearEndpoint() {
        defaults.removeObject(forKey: hostKey)
        defaults.removeObject(forKey: portKey)
    }

    private func readStoredPort() -> Int? {
        if let value = defaults.object(forKey: portKey) as? Int {
            return value
        }

        if let value = defaults.object(forKey: portKey) as? NSNumber {
            return value.intValue
        }

        if let value = defaults.string(forKey: portKey) {
            return Int(value)
        }

        return nil
    }
}
