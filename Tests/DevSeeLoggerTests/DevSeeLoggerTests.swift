import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import DevSeeLogger

private actor TransportSpy: LogTransporting {
    private(set) var events: [ApiLogEvent] = []

    func send(event: ApiLogEvent) async throws {
        events.append(event)
    }

    func latestEvent() -> ApiLogEvent? {
        events.last
    }
}

final class DevSeeLoggerTests: XCTestCase {
    func testHandleUrlValidDeepLinkReturnsConnected() throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_ip=192.168.1.23&server_port=9090"))

        let result = logger.handleURL(url)

        switch result {
        case .connected(let endpoint):
            XCTAssertEqual(endpoint, DevSeeEndpoint(scheme: "http", host: "192.168.1.23", port: 9090))
        default:
            XCTFail("Expected connected result.")
        }
    }

    func testHandleUrlMissingServerIPReturnsFailed() throws {
        let configuration = sampleConfiguration()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_port=9090"))

        let result = logger.handleURL(url)

        XCTAssertEqual(result, .failed(reason: "Missing required query parameter: server_ip."))
    }

    func testHandleUrlMissingServerPortReturnsFailed() throws {
        let configuration = sampleConfiguration()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_ip=qa-server.local"))

        let result = logger.handleURL(url)

        XCTAssertEqual(result, .failed(reason: "Missing required query parameter: server_port."))
    }

    func testHandleUrlInvalidHostReturnsFailed() throws {
        let configuration = sampleConfiguration()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_ip=qa_server.local&server_port=9090"))

        let result = logger.handleURL(url)

        XCTAssertEqual(result, .failed(reason: "Invalid host format in server_ip."))
    }

    func testHandleUrlInvalidPortReturnsFailed() throws {
        let configuration = sampleConfiguration()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let invalidURLs = [
            "dev-see-com.example.app://connect?server_ip=qa-server.local&server_port=0",
            "dev-see-com.example.app://connect?server_ip=qa-server.local&server_port=65536",
            "dev-see-com.example.app://connect?server_ip=qa-server.local&server_port=abc",
        ]

        for invalidURL in invalidURLs {
            let url = try XCTUnwrap(URL(string: invalidURL))
            let result = logger.handleURL(url)
            XCTAssertEqual(result, .failed(reason: "Invalid server_port. Use an integer between 1 and 65535."))
        }
    }

    func testHandleUrlWrongSchemeOrActionReturnsIgnored() throws {
        let configuration = sampleConfiguration()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let wrongScheme = try XCTUnwrap(URL(string: "https://connect?server_ip=qa-server.local&server_port=9090"))
        let wrongAction = try XCTUnwrap(URL(string: "dev-see-com.example.app://disconnect?server_ip=qa-server.local&server_port=9090"))

        XCTAssertEqual(logger.handleURL(wrongScheme), .ignored)
        XCTAssertEqual(logger.handleURL(wrongAction), .ignored)
    }

    func testHandleUrlAppliesEndpointOverrideAfterSuccessfulParse() throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: InMemoryEndpointStore()
        )
        let url = try XCTUnwrap(URL(string: "dev-see-com.example.app://connect?server_ip=192.168.1.34&server_port=8081"))

        let result = logger.handleURL(url)

        XCTAssertEqual(result, .connected(endpoint: DevSeeEndpoint(scheme: "http", host: "192.168.1.34", port: 8081)))
        XCTAssertEqual(logger.currentServerURL.absoluteString, "http://192.168.1.34:8081")
    }

    func testHandleURLPersistsEndpointAndRestoresOnNextInitialization() throws {
        let configuration = sampleConfiguration()
        let endpointStore = InMemoryEndpointStore()
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: endpointStore
        )
        let connectURL = try XCTUnwrap(
            URL(string: "dev-see-com.example.app://connect?server_ip=172.20.0.10&server_port=9111")
        )

        let result = logger.handleURL(connectURL)

        XCTAssertEqual(result, .connected(endpoint: DevSeeEndpoint(scheme: "http", host: "172.20.0.10", port: 9111)))
        XCTAssertEqual(
            endpointStore.storedEndpoint,
            DevSeeEndpoint(scheme: "http", host: "172.20.0.10", port: 9111)
        )

        let restartedLogger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: endpointStore
        )

        XCTAssertEqual(restartedLogger.currentServerURL.absoluteString, "http://172.20.0.10:9111")
    }

    func testIgnoredOrFailedHandleURLDoesNotOverwriteRememberedEndpoint() throws {
        let rememberedEndpoint = DevSeeEndpoint(scheme: "http", host: "10.1.1.2", port: 8080)
        let configuration = sampleConfiguration()
        let endpointStore = InMemoryEndpointStore(endpoint: rememberedEndpoint)
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: endpointStore
        )
        let ignoredURL = try XCTUnwrap(URL(string: "https://example.com"))
        let failedURL = try XCTUnwrap(
            URL(string: "dev-see-com.example.app://connect?server_ip=10.1.1.99&server_port=99999")
        )

        XCTAssertEqual(logger.handleURL(ignoredURL), .ignored)
        XCTAssertEqual(
            logger.handleURL(failedURL),
            .failed(reason: "Invalid server_port. Use an integer between 1 and 65535.")
        )
        XCTAssertEqual(endpointStore.storedEndpoint, rememberedEndpoint)
    }

    func testInvalidRememberedEndpointFallsBackToConfiguredServerURL() {
        let configuration = sampleConfiguration()
        let endpointStore = InMemoryEndpointStore(
            endpoint: DevSeeEndpoint(scheme: "http", host: "bad_host", port: 9090)
        )
        let logger = DevSeeLogger(
            configuration: configuration,
            transport: LogTransport(configuration: configuration),
            endpointStore: endpointStore
        )

        XCTAssertEqual(logger.currentServerURL.absoluteString, configuration.serverURL.absoluteString)
        XCTAssertNil(endpointStore.storedEndpoint)
    }

    func testLogMapsRequestAndResponseFields() async throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        var request = URLRequest(url: URL(string: "https://api.example.com/users?id=42")!)
        request.httpMethod = "POST"
        request.allHTTPHeaderFields = [
            "Content-Type": "application/json",
            "Authorization": "Bearer secret",
        ]

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 201,
            httpVersion: nil,
            headerFields: [
                "Content-Type": "application/json",
                "Set-Cookie": "session=abc",
            ]
        )
        XCTAssertNotNil(response)

        let requestBody = Data("{\"name\":\"Roy\"}".utf8)
        let responseBody = Data("{\"id\":42}".utf8)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endedAt = startedAt.addingTimeInterval(0.321)

        await logger.log(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            startedAt: startedAt,
            endedAt: endedAt
        )

        let event = await transportSpy.latestEvent()
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.method, "POST")
        XCTAssertEqual(event?.url, "https://api.example.com/users?id=42")
        XCTAssertEqual(event?.statusCode, 201)
        XCTAssertEqual(event?.duration, 321)
        XCTAssertEqual(event?.timestamp, Int64((endedAt.timeIntervalSince1970 * 1_000).rounded()))
        XCTAssertEqual(event?.appId, "com.example.test")
        XCTAssertEqual(event?.requestBody, "{\"name\":\"Roy\"}")
        XCTAssertEqual(event?.responseBody, "{\"id\":42}")
        XCTAssertEqual(event?.requestHeaders?["Authorization"], "[REDACTED]")
        XCTAssertEqual(event?.responseHeaders?["Set-Cookie"], "[REDACTED]")
        XCTAssertEqual(event?.requestHeaders?["Content-Type"], "application/json")
    }

    func testLogFallsBackToRequestHTTPBodyWhenRequestBodyOmitted() async throws {
        let configuration = sampleConfiguration()
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        var request = URLRequest(url: URL(string: "https://api.example.com/fallback")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"from\":\"request\"}".utf8)

        await logger.log(
            request: request,
            response: nil,
            responseBody: nil
        )

        let event = await transportSpy.latestEvent()
        XCTAssertEqual(event?.requestBody, "{\"from\":\"request\"}")
    }

    func testLogUsesExplicitRequestBodyOverRequestHTTPBody() async throws {
        let configuration = sampleConfiguration()
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        var request = URLRequest(url: URL(string: "https://api.example.com/override")!)
        request.httpMethod = "POST"
        request.httpBody = Data("{\"from\":\"request\"}".utf8)
        let explicitBody = Data("{\"from\":\"argument\"}".utf8)

        await logger.log(
            request: request,
            response: nil,
            responseBody: nil,
            requestBody: explicitBody
        )

        let event = await transportSpy.latestEvent()
        XCTAssertEqual(event?.requestBody, "{\"from\":\"argument\"}")
    }

    func testLogIncludesErrorWhenResponseUnavailable() async throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        let request = URLRequest(url: URL(string: "https://api.example.com/fail")!)
        let expectedError = URLError(.timedOut)

        await logger.log(
            request: request,
            response: nil,
            responseBody: nil,
            error: expectedError
        )

        let event = await transportSpy.latestEvent()
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.statusCode, 599)
        XCTAssertNotNil(event?.error)
        XCTAssertTrue(event?.error?.contains("NSURLErrorDomain") ?? false)
        XCTAssertTrue(event?.error?.contains("-1001") ?? false)
    }

    func testBodyOverLimitIsTruncated() async throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!,
            maxBodyBytes: 8
        )
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        let request = URLRequest(url: URL(string: "https://api.example.com/large")!)
        let oversizedBody = Data("0123456789ABCDEF".utf8)

        await logger.log(
            request: request,
            response: nil,
            responseBody: oversizedBody,
            requestBody: oversizedBody
        )

        let event = await transportSpy.latestEvent()
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.requestBody, "01234567...[TRUNCATED]")
        XCTAssertEqual(event?.responseBody, "01234567...[TRUNCATED]")
    }

    func testBodyUnderLimitIsUnchanged() async throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!,
            maxBodyBytes: 64
        )
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        let request = URLRequest(url: URL(string: "https://api.example.com/ok")!)
        let body = Data("{\"ok\":true}".utf8)

        await logger.log(
            request: request,
            response: nil,
            responseBody: body,
            requestBody: body
        )

        let event = await transportSpy.latestEvent()
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.requestBody, "{\"ok\":true}")
        XCTAssertEqual(event?.responseBody, "{\"ok\":true}")
    }

    func testLogCompletedUsesTrackedStartedAt() async throws {
        let configuration = sampleConfiguration()
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        let request = URLRequest(url: URL(string: "https://api.example.com/timed")!)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endedAt = startedAt.addingTimeInterval(0.25)
        logger.markRequestStarted(request, at: startedAt)

        await logger.logCompleted(
            request: request,
            response: nil,
            endedAt: endedAt
        )

        let event = await transportSpy.latestEvent()
        XCTAssertEqual(event?.duration, 250)
    }

    func testLogCompletedUsesTokenStartedAt() async throws {
        let configuration = sampleConfiguration()
        let transportSpy = TransportSpy()
        let logger = DevSeeLogger(configuration: configuration, transport: transportSpy)

        let request = URLRequest(url: URL(string: "https://api.example.com/token")!)
        let startedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let endedAt = startedAt.addingTimeInterval(0.123)
        let token = logger.beginRequest(request, at: startedAt)

        await logger.logCompleted(
            token: token,
            request: request,
            response: nil,
            endedAt: endedAt
        )

        let event = await transportSpy.latestEvent()
        XCTAssertEqual(event?.duration, 123)
    }

    func testTransportBuildsPostRequestWithDefaultPathAndJSONBody() throws {
        let configuration = DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
        let transport = LogTransport(configuration: configuration)
        let request = try transport.makeRequest(for: sampleEvent())

        XCTAssertEqual(request.url?.path, "/api/logs")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertNotNil(request.httpBody)
    }

    private func sampleEvent() -> ApiLogEvent {
        ApiLogEvent(
            type: "api_log",
            appId: "com.example.test",
            method: "GET",
            url: "https://api.example.com/users",
            statusCode: 200,
            duration: 42,
            timestamp: 1_700_000_000_000,
            requestHeaders: ["Accept": "application/json"],
            requestBody: nil,
            responseHeaders: ["Content-Type": "application/json"],
            responseBody: "{\"ok\":true}",
            error: nil
        )
    }

    private func sampleConfiguration() -> DevSeeLoggerConfiguration {
        DevSeeLoggerConfiguration(
            appId: "com.example.test",
            serverURL: URL(string: "http://localhost:9090")!
        )
    }
}
