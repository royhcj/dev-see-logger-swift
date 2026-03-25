import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import _Concurrency

public final class DevSeeLogger: @unchecked Sendable {
    private static let deepLinkSchemePrefix = "dev-see-"
    private static let deepLinkAction = "connect"
    private static let serverIPParam = "server_ip"
    private static let serverPortParam = "server_port"

    private let stateLock = NSLock()
    private let requestTrackingLock = NSLock()
    private var configuration: DevSeeLoggerConfiguration
    private let redactor: HeaderRedactor
    private var transport: any LogTransporting
    private let endpointStore: any DevSeeEndpointStoring
    private var startedAtsByRequestKey: [String: [Date]] = [:]
    private var startedAtsByToken: [DevSeeRequestToken: Date] = [:]

    public init(configuration: DevSeeLoggerConfiguration) {
        let endpointStore = DevSeeUserDefaultsEndpointStore(appId: configuration.appId)
        let resolvedConfiguration = Self.resolvedInitialConfiguration(
            from: configuration,
            endpointStore: endpointStore
        )
        self.configuration = resolvedConfiguration
        self.redactor = HeaderRedactor()
        self.transport = LogTransport(configuration: resolvedConfiguration)
        self.endpointStore = endpointStore
    }

    init(
        configuration: DevSeeLoggerConfiguration,
        endpointStore: any DevSeeEndpointStoring
    ) {
        let resolvedConfiguration = Self.resolvedInitialConfiguration(
            from: configuration,
            endpointStore: endpointStore
        )
        self.configuration = resolvedConfiguration
        self.redactor = HeaderRedactor()
        self.transport = LogTransport(configuration: resolvedConfiguration)
        self.endpointStore = endpointStore
    }

    init(
        configuration: DevSeeLoggerConfiguration,
        transport: any LogTransporting,
        redactor: HeaderRedactor = HeaderRedactor(),
        endpointStore: any DevSeeEndpointStoring = DevSeeNoopEndpointStore()
    ) {
        let resolvedConfiguration = Self.resolvedInitialConfiguration(
            from: configuration,
            endpointStore: endpointStore
        )
        self.configuration = resolvedConfiguration
        if transport is LogTransport, resolvedConfiguration != configuration {
            self.transport = LogTransport(configuration: resolvedConfiguration)
        } else {
            self.transport = transport
        }
        self.redactor = redactor
        self.endpointStore = endpointStore
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
        let eventWithTransport = buildEventWithTransport(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            error: error,
            startedAt: startedAt,
            endedAt: endedAt
        )
        await send(eventWithTransport.event, with: eventWithTransport.transport)
    }

    public func logDetached(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data? = nil,
        requestBody: Data? = nil,
        error: Error? = nil,
        startedAt: Date? = nil,
        endedAt: Date = Date()
    ) {
        let eventWithTransport = buildEventWithTransport(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            error: error,
            startedAt: startedAt,
            endedAt: endedAt
        )
        sendDetached(eventWithTransport.event, with: eventWithTransport.transport)
    }

    public func logText(
        _ text: String,
        tags: [String]? = nil
    ) async {
        let (_, transport) = readState()
        let event = TextLogEvent(text: text, tags: tags)
        await send(event, with: transport)
    }

    public func logTextDetached(
        _ text: String,
        tags: [String]? = nil
    ) {
        let (_, transport) = readState()
        let event = TextLogEvent(text: text, tags: tags)
        sendDetached(event, with: transport)
    }

    @discardableResult
    public func beginRequest(
        _ request: URLRequest,
        at startedAt: Date = Date()
    ) -> DevSeeRequestToken {
        let token = DevSeeRequestToken(rawValue: UUID())
        requestTrackingLock.lock()
        startedAtsByRequestKey[requestKey(for: request), default: []].append(startedAt)
        startedAtsByToken[token] = startedAt
        requestTrackingLock.unlock()
        return token
    }

    public func markRequestStarted(
        _ request: URLRequest,
        at startedAt: Date = Date()
    ) {
        requestTrackingLock.lock()
        startedAtsByRequestKey[requestKey(for: request), default: []].append(startedAt)
        requestTrackingLock.unlock()
    }

    public func logCompleted(
        token: DevSeeRequestToken? = nil,
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data? = nil,
        requestBody: Data? = nil,
        error: Error? = nil,
        endedAt: Date = Date()
    ) async {
        let startedAt = popStartedAt(token: token, for: request)
        await log(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            error: error,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    public func logCompletedDetached(
        token: DevSeeRequestToken? = nil,
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data? = nil,
        requestBody: Data? = nil,
        error: Error? = nil,
        endedAt: Date = Date()
    ) {
        let startedAt = popStartedAt(token: token, for: request)
        logDetached(
            request: request,
            response: response,
            responseBody: responseBody,
            requestBody: requestBody,
            error: error,
            startedAt: startedAt,
            endedAt: endedAt
        )
    }

    public func handleURL(_ url: URL) -> DevSeeConnectionResult {
        handleConnectionURL(url)
    }

    @available(*, deprecated, renamed: "handleURL")
    public func handleUrl(_ url: URL) -> DevSeeConnectionResult {
        handleConnectionURL(url)
    }

    private func handleConnectionURL(_ url: URL) -> DevSeeConnectionResult {
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

        guard Self.isSupportedHost(hostValue) else {
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
        endpointStore.saveEndpoint(endpoint)
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

    private static func resolvedInitialConfiguration(
        from configuration: DevSeeLoggerConfiguration,
        endpointStore: any DevSeeEndpointStoring
    ) -> DevSeeLoggerConfiguration {
        guard let rememberedEndpoint = endpointStore.loadEndpoint() else {
            return configuration
        }

        guard isSupportedHost(rememberedEndpoint.host),
              (1...65_535).contains(rememberedEndpoint.port),
              let rememberedServerURL = rememberedEndpoint.serverURL else {
            endpointStore.clearEndpoint()
            return configuration
        }

        return configuration.replacingServerURL(rememberedServerURL)
    }

    private func buildEventWithTransport(
        request: URLRequest,
        response: HTTPURLResponse?,
        responseBody: Data?,
        requestBody: Data?,
        error: Error?,
        startedAt: Date?,
        endedAt: Date
    ) -> (event: ApiLogEvent, transport: any LogTransporting) {
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
        return (event, transport)
    }

    private func send(_ event: ApiLogEvent, with transport: any LogTransporting) async {
        do {
            try await transport.send(event: event)
        } catch {
            #if DEBUG
            print("DevSeeLogger send failed: \(error)")
            #endif
        }
    }

    private func sendDetached(_ event: ApiLogEvent, with transport: any LogTransporting) {
        _Concurrency.Task {
            await send(event, with: transport)
        }
    }

    private func send(_ event: TextLogEvent, with transport: any LogTransporting) async {
        do {
            try await transport.send(event: event)
        } catch {
            #if DEBUG
            print("DevSeeLogger send failed: \(error)")
            #endif
        }
    }

    private func sendDetached(_ event: TextLogEvent, with transport: any LogTransporting) {
        _Concurrency.Task {
            await send(event, with: transport)
        }
    }

    private func popStartedAt(token: DevSeeRequestToken?, for request: URLRequest) -> Date? {
        requestTrackingLock.lock()
        defer { requestTrackingLock.unlock() }

        if let token, let startedAt = startedAtsByToken.removeValue(forKey: token) {
            let requestKey = requestKey(for: request)
            if var dates = startedAtsByRequestKey[requestKey], !dates.isEmpty {
                dates.removeFirst()
                if dates.isEmpty {
                    startedAtsByRequestKey.removeValue(forKey: requestKey)
                } else {
                    startedAtsByRequestKey[requestKey] = dates
                }
            }
            return startedAt
        }

        let requestKey = requestKey(for: request)
        guard var dates = startedAtsByRequestKey[requestKey], !dates.isEmpty else {
            return nil
        }

        let startedAt = dates.removeFirst()
        if dates.isEmpty {
            startedAtsByRequestKey.removeValue(forKey: requestKey)
        } else {
            startedAtsByRequestKey[requestKey] = dates
        }
        return startedAt
    }

    private func requestKey(for request: URLRequest) -> String {
        var hasher = Hasher()
        hasher.combine(request.httpMethod ?? "UNKNOWN")
        hasher.combine(request.url?.absoluteString ?? "")
        hasher.combine(request.httpBody ?? Data())
        return String(hasher.finalize())
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

    private static func isSupportedHost(_ host: String) -> Bool {
        isIPv4Address(host) || isHostname(host)
    }

    private static func isIPv4Address(_ host: String) -> Bool {
        let segments = host.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 4 else { return false }

        for segment in segments {
            guard !segment.isEmpty else { return false }
            guard segment.allSatisfy(\.isNumber) else { return false }
            guard let number = Int(segment), (0...255).contains(number) else { return false }
        }
        return true
    }

    private static func isHostname(_ host: String) -> Bool {
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
