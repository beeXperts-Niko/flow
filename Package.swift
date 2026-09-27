// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Flow",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Flow")
    ]
)
