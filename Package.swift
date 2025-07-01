// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
import PackageDescription

let package = Package(
    name: "AppleToolbox",
    platforms: [
        .iOS("14.0"),
        .macOS("11.4")
    ],
    products: [
        .library(name: "Macros", targets: ["Macros"]),
        .executable(name: "SwiftLintTool", targets: ["SwiftLintTool"]),
    ],
    dependencies: [
        // Depend on the Swift 5.9 release of SwiftSyntax
        .package(url: "https://github.com/swiftlang/swift-syntax", "509.0.0"..<"602.0.0"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", exact: "0.6.3"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.4.0"),
    ],
    targets: [
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.59.1/SwiftLintBinary.artifactbundle.zip",
            checksum: "b9f915a58a818afcc66846740d272d5e73f37baf874e7809ff6f246ea98ad8a2"
        ),
        .executableTarget(
            name: "SwiftLintTool",
            dependencies: [
                "SwiftLintBinary",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Plugins/SwiftLintPlugin"
        ),
        // Macro implementation that performs the source transformation of a macro.
        .macro(
            name: "MacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),
        // Library that exposes a macro as part of its API, which is used in client programs.
        .target(
            name: "Macros",
            dependencies: ["MacrosImplementation"]
        ),
        .testTarget(
            name: "MacrosTests",
            dependencies: [
                "MacrosImplementation",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "MacroTesting", package: "swift-macro-testing"),
            ]
        ),
    ]
)
