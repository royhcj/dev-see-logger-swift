import Foundation
import XCTest
@testable import DevSeeLogger

final class DevSeeLoggerCenterTests: XCTestCase {
    private var endpointStore: InMemoryEndpointStore!

    override func setUp() {
        super.setUp()
        DevSeeLoggerCenter.resetForTesting()
        endpointStore = InMemoryEndpointStore()
        DevSeeLoggerCenter.setEndpointStoreFactoryForTesting { [endpointStore] _ in
            endpointStore!
        }
    }

    override func tearDown() {
        endpointStore = nil
        DevSeeLoggerCenter.resetForTesting()
        super.tearDown()
    }

    func testConfigureUpdatesSharedLogger() {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.center",
            serverURL: URL(string: "http://localhost:9099")!
        )

        DevSeeLoggerCenter.configure(configuration)

        XCTAssertEqual(
            DevSeeLoggerCenter.shared.currentServerURL.absoluteString,
            "http://localhost:9099"
        )
    }

    func testHandleURLReturnsFalseForUnrelatedURL() throws {
        let url = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertFalse(DevSeeLoggerCenter.handleURL(url))
    }

    func testHandleURLReturnsTrueForValidDevSeeDeepLink() throws {
        DevSeeLoggerCenter.configure(
            DevSeeLoggerConfiguration(
                appId: "com.example.center",
                serverURL: URL(string: "http://localhost:9099")!
            )
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_ip=192.168.1.44&server_port=9090"))

        XCTAssertTrue(DevSeeLoggerCenter.handleURL(url))
        XCTAssertEqual(DevSeeLoggerCenter.shared.currentServerURL.absoluteString, "http://192.168.1.44:9090")
    }

    func testConfigureUsesRememberedEndpointWhenAvailable() {
        endpointStore.saveEndpoint(
            DevSeeEndpoint(scheme: "http", host: "10.10.10.5", port: 10080)
        )
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.center",
            serverURL: URL(string: "http://localhost:9099")!
        )

        DevSeeLoggerCenter.configure(configuration)

        XCTAssertEqual(
            DevSeeLoggerCenter.shared.currentServerURL.absoluteString,
            "http://10.10.10.5:10080"
        )
    }

    func testHandleURLPersistsEndpointForNextCenterBootstrap() throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.center",
            serverURL: URL(string: "http://localhost:9099")!
        )
        DevSeeLoggerCenter.configure(configuration)
        let url = try XCTUnwrap(
            URL(string: "dev-see-com.example.app://connect?server_ip=172.16.0.2&server_port=8088")
        )

        XCTAssertTrue(DevSeeLoggerCenter.handleURL(url))
        DevSeeLoggerCenter.resetForTesting()
        DevSeeLoggerCenter.setEndpointStoreFactoryForTesting { [endpointStore] _ in
            endpointStore!
        }
        DevSeeLoggerCenter.configure(configuration)

        XCTAssertEqual(
            DevSeeLoggerCenter.shared.currentServerURL.absoluteString,
            "http://172.16.0.2:8088"
        )
    }
}
