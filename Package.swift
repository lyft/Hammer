// swift-tools-version:6.0

import PackageDescription

let package = Package(
    name: "Hammer",
    platforms: [
        .iOS(.v17),
    ],
    products: [
        .library(name: "Hammer", targets: ["Hammer"]),
    ],
    targets: [
        .target(
          name: "Hammer",
          exclude: ["Info.plist"]
        ),
        // Disabled because SPM does not support running on TestHost yet
        // .testTarget(name: "HammerTests", dependencies: ["Hammer"]),
    ],
    swiftLanguageModes: [.v6]
)
