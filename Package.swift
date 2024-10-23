// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SymSpellSwift",
    platforms: [
        .iOS(.v15)
    ],
    products: [
        .library(
            name: "SymSpellSwift",
            targets: ["SymSpellSwift"])
    ],
    targets: [
        .target(
            name: "SymSpellSwift"),
        .executableTarget(
            name: "Benchmark",
            dependencies: ["SymSpellSwift"]),
        .testTarget(
            name: "SymSpellSwiftTests",
            dependencies: ["SymSpellSwift"],
            resources: [
                .process("Resources")
            ]
        )
    ]
)
