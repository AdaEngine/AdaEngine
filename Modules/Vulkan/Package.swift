// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS]

let package = Package(
    name: "Vulkan",
    products: [
        .library(
            name: "Vulkan",
            targets: ["Vulkan"]
        )
    ],
    targets: [
        .target(
            name: "Vulkan",
            dependencies: ["CVulkan"],
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
    ],
    swiftLanguageVersions: [.v5]
)
