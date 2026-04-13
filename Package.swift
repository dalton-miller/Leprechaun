// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Leprechaun",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "Leprechaun", targets: ["Leprechaun"]),
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "Leprechaun",
            path: "Sources/Leprechaun",
            resources: [
                .copy("Resources/rclone-darwin-arm64"),
                .copy("Resources/rclone-darwin-x86_64"),
            ]
        ),
    ]
)
