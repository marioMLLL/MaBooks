// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MaBooks",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ReaderCore", targets: ["ReaderCore"]),
        .library(name: "WeReadKit", targets: ["WeReadKit"]),
        .executable(name: "MaBooks", targets: ["MaBooks"])
    ],
    targets: [
        .target(name: "ReaderCore"),
        .target(name: "WeReadKit", dependencies: ["ReaderCore"]),
        .executableTarget(name: "MaBooks", dependencies: ["ReaderCore", "WeReadKit"], resources: [.process("Resources")]),
        .testTarget(name: "ReaderCoreTests", dependencies: ["ReaderCore"]),
        .testTarget(name: "WeReadKitTests", dependencies: ["WeReadKit", "ReaderCore"])
    ]
)
