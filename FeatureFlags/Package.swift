// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FeatureFlags",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "FeatureFlags",
            targets: ["FeatureFlags"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FeatureFlags",
            dependencies: [],
            path: "Sources/FeatureFlags"
        ),
        .testTarget(
            name: "FeatureFlagsTests",
            dependencies: ["FeatureFlags"],
            path: "Tests/FeatureFlagsTests"
        ),
    ]
)



