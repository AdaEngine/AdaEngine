// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

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

let package = Package(
    name: "AdaEngine",
    platforms: [
        .iOS(.v12),
        .macOS(.v11),
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/troughton/Cstb.git", from: "1.0.5"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.1")
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages this package depends on.
        .executableTarget(
            name: "AdaEditor",
            dependencies: ["AdaEngine", "Vulkan", "CSDL2", "Math"],
            exclude: ["Project.swift"]
        ),
        
        .target(
            name: "AdaEngine",
            dependencies: [
                "Vulkan",
                "Math",
                "CSDL2",
                .product(name: "stb_image", package: "Cstb"),
                .product(name: "Collections", package: "swift-collections"),
                "Yams"
            ],
            exclude: ["Project.swift"],
            resources: [
//                .copy("Rendering/Shaders/train.obj"),
//                .copy("Rendering/Shaders/train.mtl"),
//                .process("Rendering/Shaders/Metal/circle.metal")
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
        
        .target(
            name: "Math",
            exclude: ["Project.swift"]
        ),
        
        .target(
            name: "Vulkan",
            dependencies: ["CVulkan"],
            exclude: ["Project.swift"],
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
        
        // MARK: - Tests
        
        .testTarget(
            name: "AdaEngineTests",
            dependencies: ["AdaEngine"]
        ),
        
        .testTarget(
            name: "MathTests",
            dependencies: ["Math"]
        )
    ],
    swiftLanguageVersions: [.v5]
)
