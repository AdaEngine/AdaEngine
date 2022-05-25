// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

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
    
    .executable(
        name: "AdaEditor",
        targets: ["AdaEditor"]
    ),
    
        .library(
            name: "AdaEngine",
            type: .dynamic,
            targets: ["AdaEngine"]
        ),
    
        .library(
            name: "AdaEngine-Static",
            type: .static,
            targets: ["AdaEngine"]
        )
]

// TODO: It's works if we wrap sources to .swiftpm container
#if canImport(AppleProductTypes)
//let ios = Product.iOSApplication(
//    name: "AdaEditor",
//    targets: ["AdaEditor"],
//    bundleIdentifier: "dev.litecode.adaengine.editor",
//    teamIdentifier: "",
//    displayVersion: "1.0",
//    bundleVersion: "1",
//    iconAssetName: "AppIcon",
//    accentColorAssetName: "AccentColor",
//    supportedDeviceFamilies: [
//        .pad,
//        .phone
//    ],
//    supportedInterfaceOrientations: [
//        .portrait,
//        .landscapeRight,
//        .landscapeLeft,
//        .portraitUpsideDown(.when(deviceFamilies: [.pad]))
//    ]
//)
//
//products.append(ios)
#endif

// MARK: - Targets

/// Currently plugins doesn't work on swift playground and not at all binaries can work in others platforms like Windows.
#if os(macOS)
let swiftLintTargets: [Target] = [
    .binaryTarget(
        name: "SwiftLintBinary",
        path: "Binaries/SwiftLintBinary.artifactbundle"
    ),
    .plugin(
        name: "SwiftLintPlugin",
        capability: .buildTool(),
        dependencies: ["SwiftLintBinary"]
    )
]
#endif

// MARK: Editor Target

var commonPlugins: [Target.PluginUsage] = []

#if os(macOS)
commonPlugins.append(.plugin(name: "BuildPlugin"))

commonPlugins.append(.plugin(name: "SwiftLintPlugin"))
#endif

let editorTarget = Target.executableTarget(
    name: "AdaEditor",
    dependencies: ["AdaEngine", "Math"],
    exclude: ["Project.swift"],
    swiftSettings: [
        .define("EDITOR_DEBUG", .when(configuration: .debug)),
        
        // List of defines availables only for editor
        .define("EDITOR_MACOS", .when(platforms: [.macOS])),
        .define("EDITOR_WINDOWS", .when(platforms: [.windows])),
        .define("EDITOR_IOS", .when(platforms: [.iOS])),
        .define("EDITOR_TVOS", .when(platforms: [.tvOS])),
        .define("EDITOR_ANDROID", .when(platforms: [.android])),
        .define("EDITOR_LINUX", .when(platforms: [.linux]))
    ],
    plugins: commonPlugins
)

// MARK: Ada Engine SDK

let adaEngineTarget = Target.target(
    name: "AdaEngine",
    dependencies: [
        "Math",
        .product(name: "stb_image", package: "Cstb"),
        .product(name: "Collections", package: "swift-collections"),
        "Yams"
    ],
    exclude: ["Project.swift"],
    resources: [],
    swiftSettings: [
        .define("MACOS", .when(platforms: [.macOS])),
        .define("WINDOWS", .when(platforms: [.windows])),
        .define("IOS", .when(platforms: [.iOS])),
        .define("TVOS", .when(platforms: [.tvOS])),
        .define("ANDROID", .when(platforms: [.android])),
        .define("LINUX", .when(platforms: [.linux])),
        
        /// Turn on metal
        .define("METAL", .when(platforms: applePlatforms))
    ],
    plugins: commonPlugins
)

// MARK: Other Targets

var targets: [Target] = [
    
    editorTarget,
    
    adaEngineTarget,
    
        .plugin(
            name: "BuildPlugin",
            capability: Target.PluginCapability.buildTool()
        ),
    
        .target(
            name: "Math",
            exclude: ["Project.swift"]
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
]

#if os(macOS)
targets.append(contentsOf: swiftLintTargets)
#endif

let package = Package(
    name: "AdaEngine",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: products,
    dependencies: [
        .package(url: "https://github.com/troughton/Cstb.git", from: "1.0.5"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.0.1"),
        .package(url: "https://github.com/jpsim/Yams.git", from: "5.0.1"),
        
        // Plugins
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0")
    ],
    targets: targets,
    swiftLanguageVersions: [.v5]
)


// We turn on vulkan via build
if ProcessInfo.processInfo.environment["VULKAN_ENABLED"] != nil {
    
    let vulkanName = "Vulkan"
    
    let vulkanTargets: [Target] = [
        .target(
            name: vulkanName,
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
        
        .systemLibrary(
            name: "CVulkan",
            pkgConfig: "vulkan"
        ),
        
        
        //        // Just for test
        //        .systemLibrary(
        //            name: "CSDL2",
        //            pkgConfig: "sdl2",
        //            providers: [
        //                .brew(["sdl2"]),
        //                .apt(["libsdl2-dev"])
        //            ]
        //        ),
    ]
    
    package.targets.append(contentsOf: vulkanTargets)
    
    editorTarget.dependencies.append(.target(name: vulkanName))
    adaEngineTarget.dependencies.append(.target(name: vulkanName))
}


