// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ccui",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .executable(name: "ccui", targets: ["ccui"]),
    ],
    targets: [
        .executableTarget(
            name: "ccui",
            path: "Sources/ccui"
        ),
    ]
)
