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
        .executableTarget(name: "HammerCLI", dependencies: ["HammerAgentCore"]),
        // Disabled because SPM does not support running on TestHost yet
        // .testTarget(name: "HammerTests", dependencies: ["Hammer"]),
    ],
    swiftLanguageModes: [.v6]
)
