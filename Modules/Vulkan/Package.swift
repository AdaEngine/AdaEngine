// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS]

let package = Package(
    name: "Vulkan",
    products: [
        .library(
            name: "LibPNG",
            targets: ["cpng"]
        ),
        .plugin(name: "SPIR-V", targets: ["SPIRVPlugin"])
    ],
    targets: [
        .target(
            name: "Vulkan",
            dependencies: ["CVulkan"],
            exclude: ["Project.swift", "Derived"],
            cxxSettings: [
                // Apple
                .define("VK_USE_PLATFORM_IOS_MVK", .when(platforms: [.iOS])),
                .define("VK_USE_PLATFORM_MACOS_MVK", .when(platforms: [.macOS])),
                .define("VK_USE_PLATFORM_METAL_EXT", .when(platforms: applePlatforms)),
                
                // Android
                .define("VK_USE_PLATFORM_ANDROID_KHR", .when(platforms: [.android])),
                
                // Windows
                .define("VK_USE_PLATFORM_WIN32_KHR", .when(platforms: [.windows])),
            ]
        ),
        .systemLibrary(
            name: "CVulkan",
            pkgConfig: "vulkan"
        ),
        .plugin(
            name: "SPIRVBuildPlugin",
            capability: .buildTool()
        ),
        .plugin(
            name: "SPIRVPlugin",
            capability:
                    .command(
                        intent: .custom(verb: "spirv", description: "Compile vert and frag shaders to spirv binary"),
                        permissions: [
                            .writeToPackageDirectory(reason: "Compile vert and frag shaders to spirv binary")
                        ]
                    )
        )
    ],
    swiftLanguageVersions: [.v5]
)
