// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PasteDeck",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "PasteDeck",
            targets: ["PasteDeck"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "2.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PasteDeck",
            dependencies: [
                .product(name: "KeyboardShortcuts", package: "KeyboardShortcuts"),
            ],
            path: "Sources",
            exclude: [],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "PasteDeckTests",
            dependencies: ["PasteDeck"],
            path: "Tests/PasteDeckTests"
        )
    ]
)
