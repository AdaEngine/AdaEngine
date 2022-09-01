// swift-tools-version:5.6
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation

#if canImport(AppleProductTypes) && os(iOS)
import AppleProductTypes
#endif

#if os(Linux)
import Glibc
#else
import Darwin.C
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
let isVulkanEnabled = false
#else
let isVulkanEnabled = true
#endif

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS]

var products: [Product] = [
    .executable(
        name: "AdaEditor",
        targets: ["AdaEditor"]
    ),
    .library(
        name: "AdaEngine",
        targets: ["AdaEngine"]
    )
]

// Check that we target on vulkan dependency

// TODO: It's works if we wrap sources to .swiftpm container
#if canImport(AppleProductTypes) && os(iOS)
let ios = Product.iOSApplication(
    name: "AdaEditor",
    targets: ["AdaEditor"],
    bundleIdentifier: "com.adaengine.editor",
    teamIdentifier: "",
    displayVersion: "1.0",
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
    ]
)

products.append(ios)
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
commonPlugins.append(.plugin(name: "SwiftLintPlugin"))

//if isVulkanEnabled {
//    commonPlugins.append(.plugin(name: "SPIRVBuildPlugin"))
//}

#endif

var swiftSettings: [SwiftSetting] = [
    .define("MACOS", .when(platforms: [.macOS])),
    .define("WINDOWS", .when(platforms: [.windows])),
    .define("IOS", .when(platforms: [.iOS])),
    .define("TVOS", .when(platforms: [.tvOS])),
    .define("ANDROID", .when(platforms: [.android])),
    .define("LINUX", .when(platforms: [.linux])),
]

if isVulkanEnabled {
    swiftSettings.append(.define("VULKAN"))
} else {
    swiftSettings.append(.define("METAL"))
}

let editorTarget: Target = .executableTarget(
    name: "AdaEditor",
    dependencies: ["AdaEngine", "Math"],
    exclude: ["Project.swift", "Derived"],
    resources: [
        .copy("Assets")
    ],
    swiftSettings: swiftSettings + [
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

var adaEngineSwiftSettings = swiftSettings
//+ [
//    .unsafeFlags([
//        "-Xfrontend",
//        "-enable-cxx-interop",
//        "-Xfrontend",
//        "-enable-objc-interop"
//    ])
//]

var adaEngineDependencies: [Target.Dependency] = [
    "Math",
    .product(name: "stb_image", package: "Cstb"),
    .product(name: "Collections", package: "swift-collections"),
    "Yams",
    "libpng",
    "box2d",
]

#if os(Linux)
adaEngineDependencies += ["X11"]
#endif

let adaEngineTarget: Target = .target(
    name: "AdaEngine",
    dependencies: adaEngineDependencies,
    exclude: ["Project.swift", "Derived"],
    resources: [
        .copy("Assets/Shaders/Metal"),
        .copy("Assets/Models")
    ],
    swiftSettings: adaEngineSwiftSettings,
    plugins: commonPlugins
)

// MARK: Other Targets

var targets: [Target] = [
    editorTarget,
    adaEngineTarget,
    .target(
        name: "Math",
        exclude: ["Project.swift", "Derived"]
    )
]

#if os(Android) || os(Linux)
targets += [
    .systemLibrary(
        name: "X11",
        pkgConfig: "x11",
        providers: [
            .apt(["libx11-dev"])
        ]),
]
#endif

// MARK: - Tests

targets += [
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

// MARK: - Package -

let package = Package(
    name: "AdaEngine",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: products,
    dependencies: [
        .package(path: "vendors/Cstb"),
        .package(path: "vendors/swift-collections"),
        .package(path: "vendors/Yams"),
        .package(path: "vendors/libpng"),
        .package(path: "vendors/box2d"),
//        .package(path: "vendors/SPIRV-Cross-SPM"),
//        .package(path: "vendors/glslang"),
        // Plugins
        .package(path: "vendors/swift-docc-plugin"),
    ],
    targets: targets,
    swiftLanguageVersions: [.v5],
    cxxLanguageStandard: .cxx14
)

// MARK: - Vulkan
//
//// We turn on vulkan via build
//if isVulkanEnabled {
//    adaEngineTarget.dependencies.append(.target(name: "Vulkan"))
//    package.dependencies.append(.package(path: "vendors/Vulkan"))
//}
