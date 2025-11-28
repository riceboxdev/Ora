// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ImageUtils",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "ImageUtils",
            targets: ["ImageUtils"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "ImageUtils",
            dependencies: [],
            path: "Sources/ImageUtils"
        ),
        .testTarget(
            name: "ImageUtilsTests",
            dependencies: ["ImageUtils"],
            path: "Tests/ImageUtilsTests"
        ),
    ]
)



