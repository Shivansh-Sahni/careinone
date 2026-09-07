// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "CareContinuity",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "CareCore", targets: ["CareCore"])],
    targets: [
        .target(name: "CareCore", path: "CareContinuity/Core"),
        .testTarget(name: "CareCoreTests", dependencies: ["CareCore"], path: "Tests/CareCoreTests")
    ]
)
