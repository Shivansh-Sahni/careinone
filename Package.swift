// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "CareInOne",
    platforms: [.macOS(.v14), .iOS(.v18)],
    products: [.library(name: "CareCore", targets: ["CareCore"])],
    targets: [
        .target(name: "CareCore", path: "CareInOne/Core"),
        .testTarget(name: "CareCoreTests", dependencies: ["CareCore"], path: "Tests/CareCoreTests")
    ]
)
