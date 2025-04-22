// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "box2d",
    products: [
        .library(
            name: "box2d",
            targets: ["box2d"]
        )
    ],
    targets: [
        .target(
            name: "box2d",
            path: ".",
            exclude: [
                "shared",
                "samples",
                "docs",
                "benchmark",
                "extern",
                "test",
                "build.bat",
                "build.sh",
                "build_emscripten.sh",
                "CMakeLists.txt",
                "deploy_docs.sh",
                "LICENSE"
            ],
            publicHeadersPath: "include"
        )
    ]
)
