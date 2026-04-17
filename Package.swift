// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "stayawake",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "stayawake",
            path: "Sources/stayawake",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "stayawakeTests",
            dependencies: ["stayawake"],
            path: "Tests/stayawakeTests"
        ),
    ]
)
