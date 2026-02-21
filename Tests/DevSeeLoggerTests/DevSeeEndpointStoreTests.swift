import Foundation
import XCTest
@testable import DevSeeLogger

final class DevSeeEndpointStoreTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "DevSeeEndpointStoreTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testSaveAndLoadRoundTrip() {
        let store = DevSeeUserDefaultsEndpointStore(appId: "com.example.app", defaults: defaults)
        let endpoint = DevSeeEndpoint(scheme: "http", host: "192.168.0.50", port: 9090)

        store.saveEndpoint(endpoint)

        XCTAssertEqual(store.loadEndpoint(), endpoint)
    }

    func testLoadWithInvalidPortClearsStoredEndpoint() {
        let store = DevSeeUserDefaultsEndpointStore(appId: "com.example.app", defaults: defaults)
        defaults.set("qa-server.local", forKey: "devsee.logger.endpoint.com.example.app.host")
        defaults.set(70_000, forKey: "devsee.logger.endpoint.com.example.app.port")

        XCTAssertNil(store.loadEndpoint())
        XCTAssertNil(defaults.object(forKey: "devsee.logger.endpoint.com.example.app.host"))
        XCTAssertNil(defaults.object(forKey: "devsee.logger.endpoint.com.example.app.port"))
    }

    func testAppIdNamespacesValues() {
        let app1Store = DevSeeUserDefaultsEndpointStore(appId: "com.example.one", defaults: defaults)
        let app2Store = DevSeeUserDefaultsEndpointStore(appId: "com.example.two", defaults: defaults)

        app1Store.saveEndpoint(DevSeeEndpoint(scheme: "http", host: "10.0.0.1", port: 8080))

        XCTAssertEqual(app1Store.loadEndpoint(), DevSeeEndpoint(scheme: "http", host: "10.0.0.1", port: 8080))
        XCTAssertNil(app2Store.loadEndpoint())
    }
}
