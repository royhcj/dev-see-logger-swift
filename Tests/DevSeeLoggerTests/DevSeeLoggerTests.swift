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
}
