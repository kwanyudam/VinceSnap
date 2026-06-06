// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "WindowSnap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "WindowSnap",
            path: "Sources/WindowSnap"
        )
    ]
)
