// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "WeReadMac",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "ReaderCore", targets: ["ReaderCore"]),
        .library(name: "WeReadKit", targets: ["WeReadKit"]),
        .executable(name: "WeReadMac", targets: ["WeReadMac"])
    ],
    targets: [
        .target(name: "ReaderCore"),
        .target(name: "WeReadKit", dependencies: ["ReaderCore"]),
        .executableTarget(name: "WeReadMac", dependencies: ["ReaderCore", "WeReadKit"]),
        .testTarget(name: "ReaderCoreTests", dependencies: ["ReaderCore"]),
        .testTarget(name: "WeReadKitTests", dependencies: ["WeReadKit", "ReaderCore"])
    ]
)
