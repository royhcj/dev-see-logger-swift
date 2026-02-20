import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ApiLogEvent: Codable, Sendable, Equatable {
    public let type: String
    public let appId: String
    public let method: String
    public let url: String
    public let statusCode: Int
    public let duration: Int
    public let timestamp: Int64
    public let requestHeaders: [String: String]?
    public let requestBody: String?
    public let responseHeaders: [String: String]?
    public let responseBody: String?
    public let error: String?
}

extension ApiLogEvent {
    static func from(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data?,
        requestBody: Data?,
        error: Error?,
        startedAt: Date?,
        endedAt: Date,
        configuration: DevSeeLoggerConfiguration,
        redactor: HeaderRedactor
    ) -> ApiLogEvent {
        let requestHeaders = redactor.redact(request.allHTTPHeaderFields)
        let responseHeaders = redactor.redact(normalize(responseHeaders: response?.allHeaderFields))

        let encodedRequestBody = encodeBody(requestBody, maxBodyBytes: configuration.maxBodyBytes)
        let encodedResponseBody = encodeBody(responseBody, maxBodyBytes: configuration.maxBodyBytes)

        let duration = durationMilliseconds(startedAt: startedAt, endedAt: endedAt)
        let timestamp = Int64((endedAt.timeIntervalSince1970 * 1_000.0).rounded())

        let statusCode = response?.statusCode ?? 599

        let resolvedURL = request.url?.absoluteString
            ?? response?.url?.absoluteString
            ?? "about:blank"

        return ApiLogEvent(
            type: "api_log",
            appId: configuration.appId,
            method: request.httpMethod ?? "GET",
            url: resolvedURL,
            statusCode: statusCode,
            duration: duration,
            timestamp: timestamp,
            requestHeaders: requestHeaders,
            requestBody: encodedRequestBody,
            responseHeaders: responseHeaders,
            responseBody: encodedResponseBody,
            error: error.map { String(describing: $0) }
        )
    }

    private static func normalize(responseHeaders: [AnyHashable: Any]?) -> [String: String]? {
        guard let responseHeaders, !responseHeaders.isEmpty else {
            return nil
        }

        var normalized: [String: String] = [:]
        normalized.reserveCapacity(responseHeaders.count)

        for (key, value) in responseHeaders {
            normalized[String(describing: key)] = String(describing: value)
        }

        return normalized
    }

    private static func durationMilliseconds(startedAt: Date?, endedAt: Date) -> Int {
        guard let startedAt else {
            return 0
        }

        let interval = max(0, endedAt.timeIntervalSince(startedAt))
        return Int((interval * 1_000.0).rounded())
    }

    private static func encodeBody(_ data: Data?, maxBodyBytes: Int) -> String? {
        guard let data else {
            return nil
        }

        let limit = max(0, maxBodyBytes)
        let isTruncated = data.count > limit
        let bodyData: Data

        if isTruncated {
            bodyData = Data(data.prefix(limit))
        } else {
            bodyData = data
        }

        if let utf8 = String(data: bodyData, encoding: .utf8) {
            if isTruncated {
                return utf8.isEmpty ? "[TRUNCATED]" : "\(utf8)...[TRUNCATED]"
            }
            return utf8
        }

        let base64 = "base64:\(bodyData.base64EncodedString())"
        if isTruncated {
            return "\(base64)...[TRUNCATED]"
        }
        return base64
    }
}
