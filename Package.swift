// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FlowerHUD",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "FlowerHUD",
            path: "Sources/FlowerHUD"
        )
    ],
    // Keep Swift 5 semantics: this app predates strict-concurrency annotations.
    swiftLanguageVersions: [.v5]
)
