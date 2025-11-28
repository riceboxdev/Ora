// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "OraBetaAdmin",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "OraBetaAdmin",
            targets: ["OraBetaAdmin"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "OraBetaAdmin",
            dependencies: [],
            path: "Sources/OraBetaAdmin"
        ),
        .testTarget(
            name: "OraBetaAdminTests",
            dependencies: ["OraBetaAdmin"],
            path: "Tests/OraBetaAdminTests"
        ),
    ]
)










