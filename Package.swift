// swift-tools-version: 6.2
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
        name: "AdaRender",
        targets: ["AdaRender"]
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

#if os(macOS) || os(Linux)
commonPlugins.append(
    .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins")
)
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
    .define("ENABLE_DEBUG_DYLIB", .when(configuration: .debug)),
    .enableUpcomingFeature("MemberImportVisibility"),
    .strictMemorySafety(),
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

let adaEngineTarget: Target = .adaTarget(
    name: "AdaEngine",
    dependencies: adaEngineDependencies,
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

let adaEngineEmbeddable: Target = .adaTarget(
    name: "AdaEngineEmbeddable",
    dependencies: [
        "AdaEngine",
        "AdaEngineMacros"
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
    .adaTarget(name: "Math"),
    .adaTarget(
        name: "AdaApp",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaUtils",
            "AdaECS",
            "Yams"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaPlatform",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaUtils",
            "AdaECS",
            "AdaApp",
            "AdaUI"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaECS",
        dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "BitCollections", package: "swift-collections"),
            .product(name: "Atomics", package: "swift-atomics"),
            .product(name: "Logging", package: "swift-log"),
            "AdaEngineMacros",
            "AdaUtils"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaUtils",
        dependencies: [
            .product(name: "Collections", package: "swift-collections"),
            .product(name: "BitCollections", package: "swift-collections"),
            "AdaEngineMacros",
            "Math"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaUtilsTesting",
        dependencies: [
            "AdaUtils"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaAssets",
        dependencies: [
            .product(name: "Logging", package: "swift-log"),
            "AdaApp",
            "AdaUtils",
            "Yams"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
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
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaTransform",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "Math"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaRender",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaAssets",
            "AdaTransform",
            "Math",
            "Yams",
            "SPIRV-Cross",
            "SPIRVCompiler",
            "libpng",
        ],
        resources: [
            .copy("Assets/Shaders")
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaText",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
            "Math",
            "AdaRender",
            "AtlasFontGenerator",
        ],
        resources: [
            .copy("Assets")
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
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
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaInput",
        dependencies: [
            "AdaApp",
            "AdaECS",
            "AdaTransform",
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
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
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaTilemap",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "Math",
            "AdaPhysics",
            "AdaSprite"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaPhysics",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "Math",
            "box2d",
            "AdaRender"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaSprite",
        dependencies: [
            "AdaApp",
            "AdaAssets",
            "AdaECS",
            "AdaText",
            "Math",
            "AdaRender"
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
    .adaTarget(
        name: "AtlasFontGenerator",
        dependencies: [
            .product(name: "MSDFAtlasGen", package: "msdf-atlas-gen")
        ],
        publicHeadersPath: "include"
    ),
    .adaTarget(
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
        name: "AdaRenderTests",
        dependencies: [
            "AdaRender",
            "Math",
            "AdaUtilsTesting"
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
    ),
    .testTarget(
        name: "AdaUtilsTests",
        dependencies: [
            "AdaUtils",
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
        .iOS(.v17),
        .tvOS(.v17),
        .visionOS(.v2),
        .macOS(.v15),
    ],
    products: products,
    traits: [],
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
    .package(url: "https://github.com/apple/swift-atomics", from: "1.3.0"),
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "600.0.1"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.1"),

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
        .adaTarget(
            name: "Vulkan",
            dependencies: ["CVulkan"],
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

private extension Target {
    /// Creates a regular target.
    ///
    /// A target can contain either Swift or C-family source files, but not both. It contains code that is built as
    /// a regular module for inclusion in a library or executable product, but that cannot itself be used as
    /// the main target of an executable product.
    ///
    /// - Parameters:
    ///   - name: The name of the target.
    ///   - dependencies: The dependencies of the target. A dependency can be another target in the package or a product from a package dependency.
    ///   - path: The custom path for the target. By default, the Swift Package Manager requires a target's sources to reside at predefined search paths;
    ///       for example, `[PackageRoot]/Sources/[TargetName]`.
    ///       Don't escape the package root; for example, values like `../Foo` or `/Foo` are invalid.
    ///   - exclude: A list of paths to files or directories that the Swift Package Manager shouldn't consider to be source or resource files.
    ///       A path is relative to the target's directory.
    ///       This parameter has precedence over the ``sources`` parameter.
    ///   - sources: An explicit list of source files. If you provide a path to a directory,
    ///       Swift Package Manager searches for valid source files recursively.
    ///   - resources: An explicit list of resources files.
    ///   - publicHeadersPath: The directory that contains public headers of a C-family library target.
    ///   - packageAccess: Allows package symbols from other targets in the package.
    ///   - cSettings: The C settings for this target.
    ///   - cxxSettings: The C++ settings for this target.
    ///   - swiftSettings: The Swift settings for this target.
    ///   - linkerSettings: The linker settings for this target.
    ///   - plugins: The plug-ins used by this target
    static func adaTarget(
        name: String,
        dependencies: [Dependency] = [],
        path: String? = nil,
        exclude: [String] = [],
        sources: [String]? = nil,
        resources: [Resource]? = nil,
        publicHeadersPath: String? = nil,
        packageAccess: Bool = true,
        cSettings: [CSetting]? = nil,
        cxxSettings: [CXXSetting]? = nil,
        swiftSettings: [SwiftSetting]? = nil,
        linkerSettings: [LinkerSetting]? = nil,
        plugins: [PluginUsage]? = nil
    ) -> Target {
        .target(
            name: name,
            dependencies: dependencies,
            path: path,
            exclude: ["BUILD.bazel"] + exclude,
            sources: sources,
            resources: resources,
            publicHeadersPath: publicHeadersPath,
            packageAccess: packageAccess,
            cSettings: cSettings,
            cxxSettings: cxxSettings,
            swiftSettings: swiftSettings,
            linkerSettings: linkerSettings,
            plugins: plugins
        )
    }

    static func exampleTarget(
        name: String,
        path: String,
    ) -> Target {
        .executableTarget(
            name: name,
            dependencies: [
                "AdaEngine"
            ],
            path: "Assets/Examples/\(path)/\(name)",
            resources: [
                .copy("../../Resources/")
            ],
            packageAccess: false
        )
    }
}

// MARK: - Examples

let examplesTargets: [Target] = [
    // MARK: 2d
    .exampleTarget(name: "BunniesStress", path: "2d"),
    .exampleTarget(name: "TransformEntChildren", path: "2d"),
    .exampleTarget(name: "CustomMaterial", path: "2d"),
    .exampleTarget(name: "TransparencyExample", path: "2d"),

    // MARK: Input
    .exampleTarget(name: "GamepadExampleScene", path: "Input"),

    // MARK: Scene
    .exampleTarget(name: "scene_load", path: "Scene"),
    .exampleTarget(name: "LdtkTilemap", path: "Scene"),

    // MARK: Games
    .exampleTarget(name: "SnowmanAttacks", path: "Games"),

    // MARK: UI
    .exampleTarget(name: "UITestScene", path: "UI"),
    .exampleTarget(name: "AnimatedTextRenderer", path: "UI")
]

package.targets.append(contentsOf: examplesTargets)

// MARK:  Examples -
