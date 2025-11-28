// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OraLogging",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OraLogging",
            targets: ["OraLogging"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OraLogging",
            dependencies: [],
            path: "Sources/OraLogging"
        ),
        .testTarget(
            name: "OraLoggingTests",
            dependencies: ["OraLogging"],
            path: "Tests/OraLoggingTests"
        ),
    ]
)



