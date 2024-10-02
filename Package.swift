// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SymSpellSwift",
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "SymSpellSwift",
            targets: ["SymSpellSwift"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
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
