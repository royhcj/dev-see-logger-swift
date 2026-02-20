// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "dev-see-logger",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .tvOS(.v15),
        .watchOS(.v8),
    ],
    products: [
        .library(
            name: "DevSeeLogger",
            targets: ["DevSeeLogger"]
        ),
    ],
    targets: [
        .target(
            name: "DevSeeLogger"
        ),
        .testTarget(
            name: "DevSeeLoggerTests",
            dependencies: ["DevSeeLogger"]
        ),
    ]
)
