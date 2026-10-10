// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "PulseCore",
    // macOS is listed only so `swift test` runs on the Mac without a simulator.
    platforms: [.iOS("27.0"), .watchOS("27.0"), .macOS("27.0")],
    products: [.library(name: "PulseCore", targets: ["PulseCore"])],
    targets: [
        .target(name: "PulseCore"),
        .testTarget(name: "PulseCoreTests", dependencies: ["PulseCore"])
    ]
)
