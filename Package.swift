// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation
import CompilerPluginSupport

#if canImport(AppleProductTypes) && os(iOS)
import AppleProductTypes
#endif

#if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
import Darwin.C

let isVulkanEnabled = false
#else

#if os(Linux)
import Glibc
#endif

#if os(Windows)
import WinSDK
#endif

let isVulkanEnabled = false
#endif

let useLocalDeps = ProcessInfo.processInfo.environment["SWIFT_USE_LOCAL_DEPS"] != nil

let applePlatforms: [Platform] = [.iOS, .macOS, .tvOS, .watchOS, .visionOS]

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
//let swiftLintTargets: [Target] = [
//    .binaryTarget(
//        name: "SwiftLintBinary",
//        path: "Binaries/SwiftLintBinary.artifactbundle"
//    ),
//    .plugin(
//        name: "SwiftLintPlugin",
//        capability: .buildTool(),
//        dependencies: ["SwiftLintBinary"]
//    )
//]
#endif

// MARK: Editor Target

var commonPlugins: [Target.PluginUsage] = []

#if os(macOS)
//commonPlugins.append(.plugin(name: "SwiftLintPlugin"))

#endif

var swiftSettings: [SwiftSetting] = [
    .define("MACOS", .when(platforms: [.macOS])),
    .define("WINDOWS", .when(platforms: [.windows])),
    .define("IOS", .when(platforms: [.iOS])),
    .define("TVOS", .when(platforms: [.tvOS])),
    .define("VISIONOS", .when(platforms: [.visionOS])),
    .define("ANDROID", .when(platforms: [.android])),
    .define("LINUX", .when(platforms: [.linux])),
    .define("DARWIN", .when(platforms: applePlatforms)),
    .define("WASM", .when(platforms: [.wasi])),
]

if isVulkanEnabled {
    swiftSettings.append(.define("VULKAN"))
} else {
    swiftSettings.append(.define("METAL"))
}

let editorTarget: Target = .executableTarget(
    name: "AdaEditor",
    dependencies: ["AdaEngine", "Math"],
    exclude: [
        "BUILD.bazel",
        "Platforms/iOS/Info.plist",
        "Platforms/macOS/Info.plist"
    ],
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
    .product(name: "Logging", package: "swift-log"),
    "miniaudio",
    "AtlasFontGenerator",
    "Yams",
    "libpng",
    "SPIRV-Cross",
    "SPIRVCompiler",
    "box2d",
    "AdaEngineMacros"
]

#if os(Linux)
adaEngineDependencies += ["X11"]
#endif

let adaEngineTarget: Target = .target(
    name: "AdaEngine",
    dependencies: adaEngineDependencies,
    exclude: [
        "BUILD.bazel"
    ],
    resources: [
        .copy("Assets/Shaders"),
        .copy("Assets/Fonts"),
        .copy("Assets/Images")
    ],
    cSettings: [
        .define("GL_SILENCE_DEPRECATION")
    ],
    swiftSettings: adaEngineSwiftSettings,
    plugins: commonPlugins
)

let adaEngineEmbeddable: Target = .target(
    name: "AdaEngineEmbeddable",
    dependencies: [
        "AdaEngine",
        "AdaEngineMacros"
    ],
    exclude: [
        "BUILD.bazel"
    ]
)

let adaEngineMacros: Target = .macro(
    name: "AdaEngineMacros",
    dependencies: [
        .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
        .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
    ],
    exclude: [
        "BUILD.bazel"
    ]
)

// MARK: Other Targets

var targets: [Target] = [
    editorTarget,
    adaEngineTarget,
    adaEngineEmbeddable,
    adaEngineMacros,
    .target(
        name: "Math",
        exclude: [
            "BUILD.bazel"
        ]
    )
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
        publicHeadersPath: "include"
    ),
    .target(
        name: "SPIRVCompiler",
        dependencies: [
            "glslang"
        ],
        publicHeadersPath: ".",
        linkerSettings: [
            .linkedLibrary("m", .when(platforms: [.linux]))
        ]
    )
]

// MARK: - Tests

targets += [
    .testTarget(
        name: "AdaEngineTests",
        dependencies: ["AdaEngine"],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "MathTests",
        dependencies: ["Math"],
        exclude: [
            "BUILD.bazel"
        ]
    )
]

#if os(macOS)
//targets.append(contentsOf: swiftLintTargets)
#endif

// MARK: - Package -

let package = Package(
    name: "AdaEngine",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v16),
        .macOS(.v14),
    ],
    products: products,
    dependencies: [],
    targets: targets,
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)

package.dependencies += [
    .package(url: "https://github.com/apple/swift-collections", from: "1.1.1"),
    .package(url: "https://github.com/jpsim/Yams", from: "5.0.1"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1")
]

if useLocalDeps {
    package.dependencies += [
        .package(path: "Modules/LocalDeps/box2d"),
        .package(path: "Modules/LocalDeps/msdf-atlas-gen"),
        .package(path: "Modules/LocalDeps/SPIRV-Cross"),
        .package(path: "Modules/LocalDeps/glslang"),
        .package(path: "Modules/LocalDeps/miniaudio"),
        .package(path: "Modules/LocalDeps/libpng")
    ]
} else {
    package.dependencies += [
        .package(url: "https://github.com/AdaEngine/box2d", branch: "main"),
        .package(url: "https://github.com/AdaEngine/msdf-atlas-gen", branch: "master"),
        .package(url: "https://github.com/AdaEngine/SPIRV-Cross", branch: "main"),
        .package(url: "https://github.com/AdaEngine/glslang", branch: "main"),
        .package(url: "https://github.com/AdaEngine/miniaudio", branch: "master"),
        .package(url: "https://github.com/AdaEngine/libpng", branch: "main")
    ]
}

// MARK: - Vulkan -

// We turn on vulkan via build
if isVulkanEnabled {
    adaEngineTarget.dependencies.append(.target(name: "Vulkan"))
    package.targets += [
        .target(
            name: "Vulkan",
            dependencies: ["CVulkan"],
            exclude: [
                "BUILD.bazel"
            ],
            cSettings: [
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
            pkgConfig: "vulkan",
            providers: [
                .apt(["vulkan"])
            ]
        )
    ]
}
