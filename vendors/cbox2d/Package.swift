// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "box2d",
    products: [
        .library(
            name: "box2d",
            targets: ["box2d"]
        ),
        .executable(name: "Example", targets: ["Example"])
    ],
    targets: [
        .executableTarget(
            name: "Example",
            dependencies: ["box2d"],
            swiftSettings: [
                .unsafeFlags([
                    "-Xfrontend",
                    "-enable-cxx-interop",
                    "-Xfrontend",
                    "-enable-objc-interop"
                ])
            ]
        ),
        .target(
            name: "box2d",
            exclude: [
                "docs",
                "testbed",
                "unit-test"
            ]
        )
    ],
    cxxLanguageStandard: .cxx17
)
