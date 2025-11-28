// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PageableKit",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "PageableKit",
            targets: ["PageableKit"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "PageableKit",
            dependencies: [],
            path: "Sources/PageableKit"
        ),
        .testTarget(
            name: "PageableKitTests",
            dependencies: ["PageableKit"],
            path: "Tests/PageableKitTests"
        ),
    ]
)



