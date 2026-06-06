// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "VinceSnap",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "VinceSnap",
            path: "Sources/VinceSnap"
        )
    ]
)
