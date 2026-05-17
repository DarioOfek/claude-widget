// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClaudeWidget",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ClaudeWidget",
            path: "Sources/ClaudeWidget",
            exclude: ["Info.plist"]
        )
    ]
)
