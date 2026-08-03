// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Jotted",
    defaultLocalization: "zh-Hans",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "JottedCore", targets: ["JottedCore"]),
        .executable(name: "Jotted", targets: ["JottedApp"])
    ],
    targets: [
        .target(
            name: "JottedCore",
            path: "Sources/JottedCore"
        ),
        .executableTarget(
            name: "JottedApp",
            dependencies: ["JottedCore"],
            path: "Sources/JottedApp",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "JottedCoreTests",
            dependencies: ["JottedCore"],
            path: "Tests/JottedCoreTests"
        )
    ]
)
