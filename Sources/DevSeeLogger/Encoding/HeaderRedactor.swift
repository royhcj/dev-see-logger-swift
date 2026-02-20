import Foundation

public struct HeaderRedactor: Sendable {
    public static let defaultSensitiveHeaders: Set<String> = [
        "authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
    ]

    private let sensitiveHeaders: Set<String>

    public init(sensitiveHeaders: Set<String> = HeaderRedactor.defaultSensitiveHeaders) {
        self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
    }

    public func redact(_ headers: [String: String]?) -> [String: String]? {
        guard let headers, !headers.isEmpty else {
            return nil
        }

        var redacted: [String: String] = [:]
        redacted.reserveCapacity(headers.count)

        for (name, value) in headers {
            if sensitiveHeaders.contains(name.lowercased()) {
                redacted[name] = "[REDACTED]"
            } else {
                redacted[name] = value
            }
        }

        return redacted
    }
}
