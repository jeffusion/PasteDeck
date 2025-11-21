// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "PasteDeck",
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
        // Add KeyboardShortcuts dependency when ready
        // .package(url: "https://github.com/sindresorhus/KeyboardShortcuts", from: "1.0.0"),
    ],
    targets: [
        .executableTarget(
            name: "PasteDeck",
            dependencies: [],
            path: "Sources",
            exclude: []
        ),
        .testTarget(
            name: "PasteDeckTests",
            dependencies: ["PasteDeck"],
            path: "Tests/PasteDeckTests"
        )
    ]
)
