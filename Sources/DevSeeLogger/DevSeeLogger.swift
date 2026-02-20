import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class DevSeeLogger {
    private static let deepLinkSchemePrefix = "dev-see-"
    private static let deepLinkAction = "connect"
    private static let serverIPParam = "server_ip"
    private static let serverPortParam = "server_port"

    private let stateLock = NSLock()
    private var configuration: DevSeeLoggerConfiguration
    private let redactor: HeaderRedactor
    private var transport: any LogTransporting

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
        let (configuration, transport) = readState()
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

    public func handleUrl(_ url: URL) -> DevSeeConnectionResult {
        guard let scheme = url.scheme?.lowercased(),
              scheme.hasPrefix(Self.deepLinkSchemePrefix) else {
            return .ignored
        }

        guard resolvedAction(from: url) == Self.deepLinkAction else {
            return .ignored
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return .failed(reason: "Invalid connection URL.")
        }

        guard let hostValue = queryValue(Self.serverIPParam, in: components)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !hostValue.isEmpty else {
            return .failed(reason: "Missing required query parameter: \(Self.serverIPParam).")
        }

        guard isSupportedHost(hostValue) else {
            return .failed(reason: "Invalid host format in \(Self.serverIPParam).")
        }

        guard let portRaw = queryValue(Self.serverPortParam, in: components),
              !portRaw.isEmpty else {
            return .failed(reason: "Missing required query parameter: \(Self.serverPortParam).")
        }

        guard let port = Int(portRaw), (1...65_535).contains(port) else {
            return .failed(reason: "Invalid \(Self.serverPortParam). Use an integer between 1 and 65535.")
        }

        let endpoint = DevSeeEndpoint(scheme: "http", host: hostValue, port: port)
        guard let serverURL = endpoint.serverURL else {
            return .failed(reason: "Could not construct server endpoint.")
        }

        writeState(configuration: configuration.replacingServerURL(serverURL))
        return .connected(endpoint: endpoint)
    }

    var currentServerURL: URL {
        stateLock.lock()
        defer { stateLock.unlock() }
        return configuration.serverURL
    }

    private func readState() -> (DevSeeLoggerConfiguration, any LogTransporting) {
        stateLock.lock()
        defer { stateLock.unlock() }
        return (configuration, transport)
    }

    private func writeState(configuration: DevSeeLoggerConfiguration) {
        stateLock.lock()
        defer { stateLock.unlock() }
        self.configuration = configuration
        if transport is LogTransport {
            transport = LogTransport(configuration: configuration)
        }
    }

    private func resolvedAction(from url: URL) -> String {
        if let host = url.host?.lowercased(), !host.isEmpty {
            return host
        }

        let trimmedPath = url.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            .lowercased()
        return trimmedPath
    }

    private func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first(where: { $0.name == name })?.value
    }

    private func isSupportedHost(_ host: String) -> Bool {
        isIPv4Address(host) || isHostname(host)
    }

    private func isIPv4Address(_ host: String) -> Bool {
        let segments = host.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 4 else { return false }

        for segment in segments {
            guard !segment.isEmpty else { return false }
            guard segment.allSatisfy(\.isNumber) else { return false }
            guard let number = Int(segment), (0...255).contains(number) else { return false }
        }
        return true
    }

    private func isHostname(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard !labels.contains(where: \.isEmpty) else { return false }

        for label in labels {
            guard label.count <= 63 else { return false }
            guard let first = label.first, let last = label.last else { return false }
            guard first.isLetter || first.isNumber else { return false }
            guard last.isLetter || last.isNumber else { return false }
            guard label.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "-" }) else { return false }
        }
        return true
    }
}
