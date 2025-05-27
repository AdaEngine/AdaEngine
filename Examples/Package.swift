// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "Examples",
    platforms: [
        .iOS("16.0"),
        .macOS("14.0"),
        .watchOS("9.0"),
        .tvOS("16.0"),
        .visionOS("1.0")
    ],
    dependencies: [
        .package(path: "../")
    ],
    targets: [
        .executableTarget(
            name: "scene_load",
            dependencies: [
                "AdaEngine"
            ],
            resources: [
                .copy("Resources")
            ],
        ),
        .executableTarget(
            name: "scene_tilemap_physics_app",
            dependencies: [
                "AdaEngine"
            ],
            path: "Sources/scene_tilemap_physics"
        )
    ]
)