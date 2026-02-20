import Foundation

public struct DevSeeLoggerConfiguration: Sendable {
    public let appId: String
    public let serverURL: URL
    public let apiPath: String
    public let maxBodyBytes: Int

    public init(
        appId: String,
        serverURL: URL,
        apiPath: String = "/api/logs",
        maxBodyBytes: Int = 64 * 1024
    ) {
        self.appId = appId
        self.serverURL = serverURL
        self.apiPath = apiPath
        self.maxBodyBytes = max(0, maxBodyBytes)
    }

    var resolvedLogsURL: URL {
        var components = URLComponents(url: serverURL, resolvingAgainstBaseURL: false)
        var basePath = components?.path ?? ""
        if basePath.hasSuffix("/") {
            basePath.removeLast()
        }

        let normalizedAPIPath = apiPath.hasPrefix("/") ? apiPath : "/\(apiPath)"
        components?.path = "\(basePath)\(normalizedAPIPath)"
        if let resolved = components?.url {
            return resolved
        }

        guard let fallback = URL(string: normalizedAPIPath, relativeTo: serverURL)?.absoluteURL else {
            return serverURL
        }
        return fallback
    }

    func replacingServerURL(_ serverURL: URL) -> DevSeeLoggerConfiguration {
        DevSeeLoggerConfiguration(
            appId: appId,
            serverURL: serverURL,
            apiPath: apiPath,
            maxBodyBytes: maxBodyBytes
        )
    }
}
