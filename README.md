# DevSeeLogger

Swift package for sending request/response logs to a dev-see log server.

## Installation

### Swift Package Manager

Add this package to your `Package.swift` dependencies.

### CocoaPods

Add one of the following entries to your app target in `Podfile`:

```ruby
# Local development inside this monorepo
pod 'DevSeeLogger', :path => '../packages/swift/dev-see-logger'

# Or from Git (replace with your real repo URL + tag)
pod 'DevSeeLogger', :git => 'https://github.com/royhcj/dev-see-logger-swift.git', :tag => '0.2.0'
```

## Quick Start

Configure a shared logger once:

```swift
import DevSeeLogger

DevSeeLoggerCenter.configure(
    DevSeeLoggerConfiguration(
        appId: Bundle.main.bundleIdentifier ?? "com.example.app",
        serverURL: URL(string: "http://127.0.0.1:9090")!
    )
)
```

## Manual Logging

```swift
import Foundation
import DevSeeLogger

let logger = DevSeeLoggerCenter.shared

var request = URLRequest(url: URL(string: "https://api.example.com/users/42")!)
request.httpMethod = "GET"

let startedAt = Date()
do {
    let (data, response) = try await URLSession.shared.data(for: request)
    await logger.log(
        request: request,
        response: response as? HTTPURLResponse,
        responseBody: data,
        startedAt: startedAt
    )
} catch {
    await logger.log(
        request: request,
        response: nil,
        responseBody: nil,
        error: error,
        startedAt: startedAt
    )
}
```

## Lifecycle Helpers

If your networking stack provides request start and finish hooks, use lifecycle helpers:

```swift
let token = logger.beginRequest(request)
// ...perform request...
await logger.logCompleted(
    token: token,
    request: request,
    response: response as? HTTPURLResponse,
    responseBody: data,
    error: error
)
```

You can also call `markRequestStarted(_:)` and later `logCompleted(...)` without managing a token.

## Request Body Behavior

`requestBody` is optional. If omitted, logger falls back to `request.httpBody`.

## Moya Adapter

Moya integration is shipped as a separate package so the core package has no Moya dependency:

1. Add `DevSeeLoggerMoya` package from `packages/swift/dev-see-logger-moya-swift`.
2. Register plugin: `DevSeeLoggerMoyaPlugin()`.
