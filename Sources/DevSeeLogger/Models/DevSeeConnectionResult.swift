import Foundation

public struct DevSeeEndpoint: Sendable, Equatable {
    public let scheme: String
    public let host: String
    public let port: Int

    public init(scheme: String, host: String, port: Int) {
        self.scheme = scheme
        self.host = host
        self.port = port
    }

    var serverURL: URL? {
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        return components.url
    }
}

public enum DevSeeConnectionResult: Sendable, Equatable {
    case connected(endpoint: DevSeeEndpoint)
    case ignored
    case failed(reason: String)
}
