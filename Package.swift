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
        .package(url: "https://github.com/apple/swift-syntax.git", exact: "509.1.1"),
        .package(url: "https://github.com/pointfreeco/swift-macro-testing.git", exact: "0.2.2"),
        .package(url: "https://github.com/apple/swift-argument-parser.git", exact: "1.4.0"),
    ],
    targets: [
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.54.0/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "963121d6babf2bf5fd66a21ac9297e86d855cbc9d28322790646b88dceca00f1"
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
