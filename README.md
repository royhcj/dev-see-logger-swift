# DevSeeLogger

Minimal Swift Package for manually sending request/response logs to a dev-see log server.

## Installation

### Swift Package Manager

Add this package to your `Package.swift` dependencies.

### CocoaPods

Add one of the following entries to your app target in `Podfile`:

```ruby
# Local development inside this monorepo
pod 'DevSeeLogger', :path => '../packages/swift/dev-see-logger'

# Or from Git (replace with your real repo URL + tag)
pod 'DevSeeLogger', :git => 'https://github.com/your-username/dev-see.git', :tag => '0.1.0'
```

## Phase 1 Usage

```swift
import DevSeeLogger
import Foundation

let logger = DevSeeLogger(
    configuration: DevSeeLoggerConfiguration(
        appId: "com.example.myapp",
        serverURL: URL(string: "http://192.168.1.20:9090")!
    )
)

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
