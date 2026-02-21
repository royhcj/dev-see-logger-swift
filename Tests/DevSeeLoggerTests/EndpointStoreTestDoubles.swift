import Foundation
@testable import DevSeeLogger

final class InMemoryEndpointStore: @unchecked Sendable, DevSeeEndpointStoring {
    private let lock = NSLock()
    private var endpoint: DevSeeEndpoint?

    init(endpoint: DevSeeEndpoint? = nil) {
        self.endpoint = endpoint
    }

    var storedEndpoint: DevSeeEndpoint? {
        lock.lock()
        defer { lock.unlock() }
        return endpoint
    }

    func loadEndpoint() -> DevSeeEndpoint? {
        lock.lock()
        defer { lock.unlock() }
        return endpoint
    }

    func saveEndpoint(_ endpoint: DevSeeEndpoint) {
        lock.lock()
        self.endpoint = endpoint
        lock.unlock()
    }

    func clearEndpoint() {
        lock.lock()
        endpoint = nil
        lock.unlock()
    }
}
