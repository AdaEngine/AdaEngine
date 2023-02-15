// swift-tools-version:5.7
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

#if (arch(arm64) || arch(arm))
let useNeon = true
#else
let useNeon = false
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
    ),
    .library(
        name: "AdaEngineEmbeddable",
        targets: ["AdaEngineEmbeddable"]
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

var adaEngineDependencies: [Target.Dependency] = [
    "Math",
    .product(name: "Collections", package: "swift-collections"),
    "Yams",
    "libpng",
    "box2d"
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

let adaEngineEmbeddable: Target = .target(
    name: "AdaEngineEmbeddable",
    dependencies: ["AdaEngine"],
    exclude: ["Project.swift", "Derived"]
)

// MARK: Other Targets

var targets: [Target] = [
    editorTarget,
    adaEngineTarget,
    adaEngineEmbeddable,
    .target(
        name: "Math",
        exclude: ["Project.swift", "Derived"]
    )
]

// MARK: Documentations

targets += [
    // Empty target with documentation docc files
    .target(name: "Documentation")
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

// MARK: - Vendors -

// libpng

targets += [
    .target(
        name: "libpng",
        exclude: ["Project.swift", "Derived"],
        cSettings: [
            .define("PNG_ARM_NEON_OPT", to: useNeon ? "2" : "0")
        ]
    )
]

// box2d

targets += [
    .target(
        name: "box2d",
        exclude: ["Project.swift", "Derived"]
    )
]

// MARK: - Package -

let package = Package(
    name: "AdaEngine",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
    ],
    products: products,
    dependencies: [ ],
    targets: targets,
    swiftLanguageVersions: [.v5],
    cxxLanguageStandard: .cxx14
)

// FIXME: If possible - move to local `vendors` folder
package.dependencies += [
    .package(url: "https://github.com/apple/swift-collections", from: "1.0.4"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.1"),
    
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
]

// MARK: - Vulkan -
//
//// We turn on vulkan via build
//if isVulkanEnabled {
//    adaEngineTarget.dependencies.append(.target(name: "Vulkan"))
//    package.dependencies.append(.package(path: "vendors/Vulkan"))
//}
