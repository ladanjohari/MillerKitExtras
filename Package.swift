// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MillerKitExtras",
    platforms: [.macOS(.v14)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MillerKitExtras",
            targets: ["MillerKitExtras"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-llbuild2", branch: "main"),
        .package(url: "https://github.com/apple/swift-async-algorithms", branch: "main"),
        .package(url: "https://github.com/apple/swift-collections", branch: "1.1.4"),
        .package(url: "https://github.com/swiftlang/swift-markdown", branch: "swift-markdown-0.5"),
        .package(url: "https://github.com/google-gemini/generative-ai-swift", branch: "0.5.6"),
        .package(url: "https://github.com/pointfreeco/swift-html", branch: "0.5.0"),
        .package(url: "https://github.com/tree-sitter/tree-sitter-cpp", branch: "v0.23.4"),
        .package(url: "https://github.com/ladanjohari/MillerKit", branch: "1.25")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MillerKitExtras",
            dependencies: [
                .product(name: "llbuild2", package: "swift-llbuild2"),
                .product(name: "llbuild2fx", package: "swift-llbuild2"),
                .product(name: "MillerKit", package: "MillerKit"),
                .product(name: "Markdown", package: "swift-markdown"),
                "MillerKitGemini",
                .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
                .product(name: "Collections", package: "swift-collections"),
                .product(name: "Html", package: "swift-html")
            ]
        ),
        .target(
            name: "MillerKitGemini",
            dependencies: [
                .product(name: "llbuild2", package: "swift-llbuild2"),
                .product(name: "llbuild2fx", package: "swift-llbuild2"),
                .product(name: "MillerKit", package: "MillerKit"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
            ]
        ),
        .testTarget(
            name: "MillerKitExtrasTests",
            dependencies: ["MillerKitExtras"]
        ),
    ]
)
