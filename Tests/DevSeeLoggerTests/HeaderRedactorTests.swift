import XCTest
@testable import DevSeeLogger

final class HeaderRedactorTests: XCTestCase {
    func testDefaultSensitiveHeadersAreRedacted() {
        let redactor = HeaderRedactor()
        let headers: [String: String] = [
            "Authorization": "Bearer secret",
            "Cookie": "session=abc",
            "Set-Cookie": "id=123",
            "X-API-Key": "key-value",
            "Accept": "application/json",
        ]

        let redacted = redactor.redact(headers)

        XCTAssertEqual(redacted?["Authorization"], "[REDACTED]")
        XCTAssertEqual(redacted?["Cookie"], "[REDACTED]")
        XCTAssertEqual(redacted?["Set-Cookie"], "[REDACTED]")
        XCTAssertEqual(redacted?["X-API-Key"], "[REDACTED]")
    }

    func testNonSensitiveHeadersArePreserved() {
        let redactor = HeaderRedactor()
        let headers: [String: String] = [
            "Accept": "application/json",
            "Content-Type": "application/json",
        ]

        let redacted = redactor.redact(headers)

        XCTAssertEqual(redacted?["Accept"], "application/json")
        XCTAssertEqual(redacted?["Content-Type"], "application/json")
    }
}
