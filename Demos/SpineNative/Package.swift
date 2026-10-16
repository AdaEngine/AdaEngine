// swift-tools-version: 6.2
import Foundation
import PackageDescription

let mcpPath = ProcessInfo.processInfo.environment["ADA_MCP_LOCAL_PATH"]
let package = Package(
    name: "SpineNative",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(name: "AdaEngine", path: "../.."),
        mcpPath.map { .package(name: "AdaMCP", path: $0) }
            ?? .package(url: "https://github.com/AdaEngine/AdaMCP.git", revision: "v0.2.0"),
    ],
    targets: [
        .executableTarget(
            name: "SpineNative",
            dependencies: [
                .product(name: "AdaEngine", package: "AdaEngine"),
                .product(name: "AdaSpine", package: "AdaEngine"),
                .product(name: "AdaMCPPlugin", package: "AdaMCP"),
            ],
            path: ".",
            exclude: ["README.md", "capture.py"],
            sources: ["SpineNativeApp.swift"]
        ),
    ]
)
