// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FirebaseUtils",
    platforms: [
        .iOS(.v15),
        .macOS(.v12)
    ],
    products: [
        .library(
            name: "FirebaseUtils",
            targets: ["FirebaseUtils"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FirebaseUtils",
            dependencies: [],
            path: "Sources/FirebaseUtils"
        ),
        .testTarget(
            name: "FirebaseUtilsTests",
            dependencies: ["FirebaseUtils"],
            path: "Tests/FirebaseUtilsTests"
        ),
    ]
)



