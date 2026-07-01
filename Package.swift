// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ReachMonitor",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ReachMonitor",
            path: "Sources/ReachMonitor"
        )
    ],
    // Use the Swift 5 language mode to avoid strict-concurrency friction with
    // the callback-based Network / CoreWLAN APIs. UI updates are still funneled
    // onto the main actor explicitly.
    swiftLanguageModes: [.v5]
)
