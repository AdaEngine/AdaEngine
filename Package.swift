// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation
import CompilerPluginSupport

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

let useLocalDeps = ProcessInfo.processInfo.environment["SWIFT_USE_LOCAL_DEPS"] != nil

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
    .interoperabilityMode(.Cxx)
]

if isVulkanEnabled {
    swiftSettings.append(.define("VULKAN"))
} else {
    swiftSettings.append(.define("METAL"))
}

let editorTarget: Target = .executableTarget(
    name: "AdaEditor",
    dependencies: ["AdaEngine", "Math"],
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
        .define("EDITOR_LINUX", .when(platforms: [.linux])),
    ],
    plugins: commonPlugins
)

// MARK: Ada Engine SDK

var adaEngineSwiftSettings = swiftSettings

var adaEngineDependencies: [Target.Dependency] = [
    "Math",
    .product(name: "Collections", package: "swift-collections"),
    .product(name: "BitCollections", package: "swift-collections"),
    "MiniAudioBindings",
    "AtlasFontGenerator",
    "Yams",
    "libpng",
    "SPIRV-Cross",
    "SPIRVCompiler",
    "AdaBox2d",
    "AdaEngineMacros"
//    "Vulkan"
]

#if os(Linux)
adaEngineDependencies += ["X11"]
#endif

let adaEngineTarget: Target = .target(
    name: "AdaEngine",
    dependencies: adaEngineDependencies,
    resources: [
        .copy("Assets/Shaders"),
        .copy("Assets/Fonts")
    ],
    swiftSettings: adaEngineSwiftSettings,
    linkerSettings: [
        .linkedLibrary("c++")
    ],
    plugins: commonPlugins
)

let adaEngineEmbeddable: Target = .target(
    name: "AdaEngineEmbeddable",
    dependencies: ["AdaEngine"]
)

let adaEngineMacros: Target = .macro(
    name: "AdaEngineMacros",
    dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
    ]
)

// MARK: Other Targets

var targets: [Target] = [
    editorTarget,
    adaEngineTarget,
    adaEngineEmbeddable,
    adaEngineMacros,
    .target(name: "Math")
]

// MARK: Extra

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

// MARK: - CXX Internal Targets

targets += [
    .target(
        name: "AtlasFontGenerator",
        dependencies: [
            .product(name: "MSDFAtlasGen", package: "msdf-atlas-gen")
        ],
        publicHeadersPath: "."
    ),
    .target(
        name: "MiniAudioBindings",
        dependencies: [
            "miniaudio",
        ],
        publicHeadersPath: "."
    ),
    .target(
        name: "SPIRVCompiler",
        dependencies: [
            "glslang"
        ],
        publicHeadersPath: "."
    ),
    .target(
        name: "AdaBox2d",
        dependencies: [
            .product(name: "box2d", package: "box2d-swift")
        ],
        publicHeadersPath: "."
    )
]

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
        .iOS(.v14),
        .macOS(.v11),
    ],
    products: products,
    dependencies: [],
    targets: targets,
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)

package.dependencies += [
    .package(url: "https://github.com/apple/swift-collections", branch: "main"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.1"),
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-syntax", from: "509.1.1")
]

if useLocalDeps {
    package.dependencies += [
        .package(path: "../box2d-swift"),
        .package(path: "../msdf-atlas-gen"),
        .package(path: "../SPIRV-Cross"),
        .package(path: "../glslang"),
        .package(path: "../miniaudio"),
        .package(path: "../libpng"),
    ]
} else {
    package.dependencies += [
        .package(url: "https://github.com/AdaEngine/box2d-swift", branch: "main"),
        .package(url: "https://github.com/AdaEngine/msdf-atlas-gen", branch: "master"),
        .package(url: "https://github.com/AdaEngine/SPIRV-Cross", branch: "main"),
        .package(url: "https://github.com/AdaEngine/glslang", branch: "main"),
        .package(url: "https://github.com/AdaEngine/miniaudio", branch: "master"),
        .package(url: "https://github.com/AdaEngine/libpng", branch: "main"),
    ]
}

// MARK: - Vulkan -
//
//// We turn on vulkan via build
//if isVulkanEnabled {
//    adaEngineTarget.dependencies.append(.target(name: "Vulkan"))
//    package.dependencies.append(.package(path: "vendors/Vulkan"))
//}
