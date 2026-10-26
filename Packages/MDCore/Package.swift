// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MDCore",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
    ],
    products: [
        .library(name: "MDCore", targets: ["MDCore"]),
    ],
    targets: [
        .target(name: "MDCore"),
        .testTarget(
            name: "MDCoreTests",
            dependencies: ["MDCore"],
        ),
    ],
)
