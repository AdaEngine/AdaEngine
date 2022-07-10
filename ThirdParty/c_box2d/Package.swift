// swift-tools-version: 5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Box2DSwift",
    products: [
        .library(
            name: "Box2DSwift",
            type: .static,
            targets: ["Box2DSwift"]
        ),
        .executable(name: "Test", targets: ["Test"])
    ],
    targets: [
        .target(
            name: "box2d"
        ),
        
        .target(
            name: "Box2DSwift",
            dependencies: [
                "box2d"
            ],
            swiftSettings: [
                /// For c++ interop
                .unsafeFlags([
                    "-Xfrontend", "-enable-cxx-interop",
                    "-Xfrontend", "-enable-objc-interop",
                    "-I", "Sources/box2d/src",
                    "-I", "Sources/box2d/include",
                ])
            ]
        ),
        .executableTarget(
            name: "Test",
            dependencies: [
                "Box2DSwift"
            ],
            swiftSettings: [
                /// For c++ interop
                .unsafeFlags([
                    "-Xfrontend", "-enable-cxx-interop",
                    "-Xfrontend", "-enable-objc-interop",
                    "-I", "Sources/box2d/src",
                    "-I", "Sources/box2d/include",
                ])
            ]
        )
    ],
    cxxLanguageStandard: .cxx11
)
