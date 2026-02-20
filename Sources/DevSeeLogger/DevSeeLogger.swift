import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class DevSeeLogger {
    private let configuration: DevSeeLoggerConfiguration
    private let redactor: HeaderRedactor
    private let transport: any LogTransporting

    public init(configuration: DevSeeLoggerConfiguration) {
        self.configuration = configuration
        self.redactor = HeaderRedactor()
        self.transport = LogTransport(configuration: configuration)
    }

    init(
        configuration: DevSeeLoggerConfiguration,
        transport: any LogTransporting,
        redactor: HeaderRedactor = HeaderRedactor()
    ) {
        self.configuration = configuration
        self.transport = transport
        self.redactor = redactor
    }

    public func log(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data?,
        requestBody: Data? = nil,
        error: Error? = nil,
        startedAt: Date? = nil,
        endedAt: Date = Date()
    ) async {
        let event = ApiLogEvent.from(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            error: error,
            startedAt: startedAt,
            endedAt: endedAt,
            configuration: configuration,
            redactor: redactor
        )

        do {
            try await transport.send(event: event)
        } catch {
            #if DEBUG
            print("DevSeeLogger send failed: \(error)")
            #endif
        }
    }
}
