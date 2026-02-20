# DevSeeLogger

Minimal Swift Package for manually sending request/response logs to a dev-see log server.

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
