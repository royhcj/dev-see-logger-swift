import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

protocol LogTransporting: Sendable {
    func send(event: ApiLogEvent) async throws
}

public final class LogTransport: LogTransporting {
    private let configuration: DevSeeLoggerConfiguration
    private let session: URLSession
    private let encoder: JSONEncoder

    public init(
        configuration: DevSeeLoggerConfiguration,
        session: URLSession = .shared
    ) {
        self.configuration = configuration
        self.session = session

        let encoder = JSONEncoder()
        self.encoder = encoder
    }

    public func send(event: ApiLogEvent) async throws {
        let request = try makeRequest(for: event)
        _ = try await session.data(for: request)
    }

    func makeRequest(for event: ApiLogEvent) throws -> URLRequest {
        var request = URLRequest(url: configuration.resolvedLogsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(event)
        return request
    }
}
