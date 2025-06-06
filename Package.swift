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
        name: "AdaECS",
        targets: ["AdaECS"]
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

// MARK: Editor Target

var commonPlugins: [Target.PluginUsage] = []

var swiftSettings: [SwiftSetting] = [
    .define("MACOS", .when(platforms: [.macOS])),
    .define("WINDOWS", .when(platforms: [.windows])),
    .define("IOS", .when(platforms: [.iOS])),
    .define("TVOS", .when(platforms: [.tvOS])),
    .define("VISIONOS", .when(platforms: [.visionOS])),
    .define("ANDROID", .when(platforms: [.android])),
    .define("LINUX", .when(platforms: [.linux])),
    .define("DARWIN", .when(platforms: applePlatforms)),
    .define("WASM", .when(platforms: [.wasi]))
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
    "AdaApp",
    "AdaECS",
    "AdaUI",
    "AdaEngineMacros",
    "AdaAssets",
    "AdaPlatform",
    "AdaAudio",
    "AdaTransform",
    "AdaRender",
    "AdaText",
    "AdaInput",
    "AdaScene",
    "AdaTilemap",
    "AdaPhysics"
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
        .copy("Assets/Images"),
        .copy("Assets/Shaders")
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
    ),
    .target(
        name: "AdaApp",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaUtils",
            "AdaECS",
            "Yams"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaPlatform",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaUtils",
            "AdaECS",
            "AdaApp",
            "AdaUI"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaECS",
        dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "BitCollections", package: "swift-collections"),
            "AdaEngineMacros",
            "AdaUtils"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaUtils",
        dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "BitCollections", package: "swift-collections"),
            "AdaEngineMacros",
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaAssets",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaApp",
            "AdaUtils",
            "Yams"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaAudio",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaUtils",
            "AdaAssets",
            "AdaTransform",
            "miniaudio",
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaTransform",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaRender",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
            "Math",
            "Yams",
            "SPIRV-Cross",
            "SPIRVCompiler",
            "libpng",
        ],
        exclude: [
            "BUILD.bazel"
        ],
        resources: [
            .copy("Assets/Shaders")
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaText",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
            "Math",
            "AdaRender",
            "AtlasFontGenerator",
        ],
        exclude: [
            "BUILD.bazel"
        ],
        resources: [
            .copy("Assets")
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaUI",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
            "AdaText",
            "Math",
            "AdaRender",
            "AdaInput",
            "AdaEngineMacros",
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaInput",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaScene",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "box2d",
            "AdaTransform",
            "AdaText",
            "AdaAudio",
            "AdaRender",
            "AdaUI",
            "AdaPhysics"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaTilemap",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "Math",
            "AdaPhysics",
            "AdaSprite"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaPhysics",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "Math",
            "box2d",
            "AdaRender"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        swiftSettings: swiftSettings
    ),
    .target(
        name: "AdaSprite",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "Math",
            "AdaRender"
        ],
        exclude: [
            "BUILD.bazel"
        ],
        resources: [
            .copy("Assets")
        ],
        swiftSettings: swiftSettings
    ),
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
        dependencies: [
            .product(name: "Numerics", package: "swift-numerics"),
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "AdaECSTests",
        dependencies: ["AdaECS", "Math"],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "AdaAssetsTests",
        dependencies: [
            "AdaAssets",
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "AdaTransformTests",
        dependencies: [
            "AdaECS", 
            "AdaTransform",
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "AdaUITests",
        dependencies: [
            "AdaUI",
            "AdaPlatform",
            "AdaUtils",
            "AdaInput",
            "Math"
        ],
        exclude: [
            "BUILD.bazel"
        ]
    ),
    .testTarget(
        name: "AdaInputTests",
        dependencies: [
            "AdaInput",
            "AdaUI",
            "Math"
        ],
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
    .package(url: "https://github.com/SpectralDragon/Yams.git", revision: "fb676da"),
    .package(url: "https://github.com/apple/swift-log", from: "1.5.4"),
    .package(url: "https://github.com/apple/swift-numerics", from: "1.0.0"),
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),

    .package(path: "Modules/box2d"),
    .package(path: "Modules/msdf-atlas-gen"),
    .package(path: "Modules/SPIRV-Cross"),
    .package(path: "Modules/glslang"),
    .package(path: "Modules/miniaudio"),
    .package(path: "Modules/libpng")
]

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
