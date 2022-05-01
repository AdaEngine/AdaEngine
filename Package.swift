// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

#if canImport(AppleProductTypes)
import AppleProductTypes
#endif

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS]

var products: [Product] = [
    .library(
        name: "AdaEngine",
        type: .dynamic,
        targets: ["AdaEngine"]
    ),
    
    .executable(
        name: "AdaEditor",
        targets: ["AdaEditor"]
    )
]

#if canImport(AppleProductTypes)
products.append(
    .iOSApplication(
        name: "AdaEditor",
        targets: ["AdaEditor"],
        bundleIdentifier: "dev.litecode.adaeditor",
        teamIdentifier: nil,
        displayVersion: "0.1.0",
        bundleVersion: "1",
        iconAssetName: "AppIcon",
        accentColorAssetName: "AccentColor",
        supportedDeviceFamilies: [
            .pad,
            .phone
        ],
        supportedInterfaceOrientations: [
            .portrait,
            .landscapeRight,
            .landscapeLeft,
            .portraitUpsideDown(.when(deviceFamilies: [.pad]))
        ],
        capabilities: [],
        additionalInfoPlistContentFilePath: nil
    )
)
#endif

let package = Package(
    name: "AdaEngine",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
    ],
    products: products,
    dependencies: [
        .package(name: "SGLMath", url: "https://github.com/SwiftGL/Math.git", from: "3.0.0"), // TODO: remove it later
        .package(url: "https://github.com/troughton/Cstb.git", from: "1.0.5"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "AdaEditor",
            dependencies: ["AdaEngine", "Vulkan", "CSDL2", "Math"]
        ),
        
        .target(
            name: "AdaEngine",
            dependencies: [
                "Vulkan",
                "Math",
                "CSDL2",
                "SGLMath",
                .product(name: "stb_image", package: "Cstb"),
                .product(name: "Collections", package: "swift-collections")
            ],
            resources: [
                .copy("Rendering/Shaders/train.obj"),
                .copy("Rendering/Shaders/train.mtl"),
                .process("Rendering/Shaders/Metal/*.metal")
            ]
        ),
        
        // Just for test
        .systemLibrary(
                name: "CSDL2",
                pkgConfig: "sdl2",
                providers: [
                    .brew(["sdl2"]),
                    .apt(["libsdl2-dev"])
                ]
        ),
        
        .systemLibrary(
            name: "CVulkan",
            pkgConfig: "vulkan"
        ),
        
        .target(name: "Math"),
        
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
        
        .testTarget(
            name: "AdaEngineTests",
            dependencies: ["AdaEngine"]
        ),
    ],
    swiftLanguageVersions: [.v5]
)
