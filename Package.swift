// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NHV",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [.library(name: "NHVCore", targets: ["NHVCore"])],
    targets: [
        .target(name: "NHVCore"),
        .testTarget(name: "NHVCoreTests", dependencies: ["NHVCore"])
    ]
)
