import Foundation
import XCTest
@testable import DevSeeLogger

final class DevSeeLoggerCenterTests: XCTestCase {
    override func setUp() {
        super.setUp()
        DevSeeLoggerCenter.resetForTesting()
    }

    override func tearDown() {
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
}
