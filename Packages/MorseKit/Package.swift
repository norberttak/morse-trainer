// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MorseKit",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "MorseKit", targets: ["MorseKit"]),
    ],
    targets: [
        .target(name: "MorseKit"),
        .testTarget(name: "MorseKitTests", dependencies: ["MorseKit"]),
    ]
)
