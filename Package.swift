// swift-tools-version: 6.1
import PackageDescription

// Pedalboard — a menu bar app that mutes every microphone but the ones you
// keep live, in one click.
//
// Layering rule: `PedalboardCore` is pure logic with no SwiftUI and no AppKit
// (CoreAudio is fine — it is not a UI framework), so the muting rules are
// testable with `swift test` without launching a GUI, and the app and the CLI
// share one core. `make check` enforces this — see the lint-layers target.
let package = Package(
    name: "Pedalboard",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        // The bundle is Pedalboard.app; the executable inside is
        // PedalboardApp, so it never collides with the `pedal` CLI.
        .executable(name: "PedalboardApp", targets: ["PedalboardApp"]),
        .executable(name: "pedal", targets: ["pedal"]),
        .library(name: "PedalboardCore", targets: ["PedalboardCore"]),
    ],
    targets: [
        // CoreAudio devices and the mute/restore rules.
        .target(name: "PedalboardCore"),

        // Frontends.
        .executableTarget(
            name: "PedalboardApp",
            dependencies: ["PedalboardCore"],
            path: "Sources/PedalboardApp"
        ),
        .executableTarget(
            name: "pedal",
            dependencies: ["PedalboardCore"],
            path: "Sources/PedalboardCLI"
        ),

        // Tests.
        .testTarget(name: "PedalboardCoreTests", dependencies: ["PedalboardCore"]),
    ],
    swiftLanguageModes: [.v6]
)
