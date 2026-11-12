// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Hammer",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "Hammer", targets: ["Hammer"]),
        .library(name: "HammerAgent", targets: ["HammerAgent"]),
        .executable(name: "hammer", targets: ["HammerCLI"]),
    ],
    targets: [
        .target(
          name: "Hammer",
          exclude: ["Info.plist"]
        ),
        .target(name: "HammerAgentCore"),
        .target(name: "HammerAgent", dependencies: ["Hammer", "HammerAgentCore"]),
        // zlib, for the PNGs of Android screenshots, which macOS and Linux both ship
        .systemLibrary(name: "CZlib"),
        .executableTarget(name: "HammerCLI", dependencies: ["HammerAgentCore", "CZlib"]),
        // Runs on macOS with `swift build --target HammerCLITests && swift test --skip-build`, and on Linux
        // with `swift build --product HammerPackageTests && swift test --skip-build`
        .testTarget(name: "HammerCLITests", dependencies: ["HammerCLI"], resources: [.copy("Fixtures")]),
        // Disabled because SPM does not support running on TestHost yet
        // .testTarget(name: "HammerTests", dependencies: ["Hammer"]),
    ],
    swiftLanguageModes: [.v6]
)
