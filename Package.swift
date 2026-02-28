// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeVillage",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.65.0"),
    ],
    targets: [
        // Pure-Swift simulation library (NO SpriteKit/AppKit — runs on Linux too)
        .target(
            name: "VillageSimulation",
            path: "VillageSimulation",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

        // macOS native app (SpriteKit + SwiftUI renderer)
        .executableTarget(
            name: "ClaudeVillage",
            dependencies: ["VillageSimulation"],
            path: "ClaudeVillage",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),

        // Headless server (HTTP + WebSocket, runs on Linux/macOS)
        .executableTarget(
            name: "VillageServer",
            dependencies: [
                "VillageSimulation",
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOPosix", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOWebSocket", package: "swift-nio"),
            ],
            path: "VillageServer",
            exclude: ["public"],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
