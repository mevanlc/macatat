// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "macatat",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "MacatatCore"),
        .executableTarget(name: "macatat", dependencies: ["MacatatCore"]),
        .testTarget(name: "MacatatCoreTests", dependencies: ["MacatatCore"]),
    ]
)
