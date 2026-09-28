// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Blink",
    platforms: [.macOS(.v14)],
    targets: [
        // Head-tracking logic: pure Foundation, no UI, so it can be simulated.
        .target(name: "BlinkCore"),
        // The menu bar app. Build the .app bundle with scripts/build-app.sh.
        .executableTarget(name: "Blink", dependencies: ["BlinkCore"]),
        // Deterministic scenario tests for BlinkCore: `swift run BlinkSimulation`.
        // (An executable rather than XCTest, which needs a full Xcode install.)
        .executableTarget(name: "BlinkSimulation", dependencies: ["BlinkCore"], path: "Tests/BlinkSimulation"),
    ]
)
