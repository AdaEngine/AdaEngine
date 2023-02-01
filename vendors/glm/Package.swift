// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "glm",
    products: [
        .executable(name: "Test", targets: ["Test"]),
        
        .library(
            name: "glm",
            targets: ["glm"]
        )
    ],
    targets: [
        .executableTarget(
            name: "Test",
            dependencies: [
                "glm"
            ],
            path: "Example",
            swiftSettings: [
                .unsafeFlags([
                    "-enable-experimental-cxx-interop"
                ]),
            ]
        ),
        .target(
            name: "glm",
            path: "glm",
            publicHeadersPath: ".",
            cxxSettings: [
                .define("GLM_FORCE_MESSAGES"),
                .define("GLM_FORCE_ALIGNED_GENTYPES"),
                .define("_MSC_EXTENSIONS")
            ]
        ),
    ],
    cxxLanguageStandard: .cxx14
)
