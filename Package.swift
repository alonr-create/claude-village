// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClaudeVillage",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "ClaudeVillage",
            path: "ClaudeVillage",
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        )
    ]
)
