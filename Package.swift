// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation
import CompilerPluginSupport

#if canImport(AppleProductTypes)
import AppleProductTypes
#endif

#if canImport(Darwin)
import Darwin.C

/// Only xcode can import AppleProductTypes and we can use it as checker
#if canImport(AppleProductTypes)
let isWGPUEnabled = false // We can't build wgpu from xcode
#else
let isWGPUEnabled = true
#endif

#else

#if os(Linux)
import Glibc
#endif

#if os(Windows)
import WinSDK
#endif

let isWGPUEnabled = true
#endif

extension String {
    static let wgpuTrait = "WGPU_ENABLED"
}

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
    ),
    .plugin(name: "WebGPUBuildPlugin", targets: [
        "WebGPUBuildPlugin"
    ])
]

// Check that we target on vulkan dependency

// TODO: It's works if we wrap sources to .swiftpm container and run in Swift Plaground App
#if canImport(AppleProductTypes)
let ios = Product.iOSApplication(
    name: "AdaEditor-iOS",
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

// Xcode crashed after that move...
// products.append(ios)
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
    .define("METAL", .when(platforms: applePlatforms)),
    .define("WEBGPU_ENABLED", .when(traits: [.wgpuTrait])),
    .define("WASM", .when(platforms: [.wasi])),
    .define("ENABLE_DEBUG_DYLIB", .when(configuration: .debug)),
    .define("ENABLE_RUN_IN_CONCURRENCY", .when(platforms: [.windows, .wasi, .android, .linux])),
    .enableUpcomingFeature("MemberImportVisibility"),
    .strictMemorySafety(),
    .unsafeFlags(["-Xfrontend", "-validate-tbd-against-ir=none"]),
]

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
        .copy("Assets/Images")
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
            "AdaUtils",
            "AdaECS",
            "Yams"
        ],
        swiftSettings: swiftSettings
    ),
    .adaTarget(
        name: "AdaPlatform",
        dependencies: [
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
        name: "AdaCorePipelines",
        dependencies: [
            "AdaECS",
            "AdaApp",
            "AdaRender",
            "Math"
        ],
        resources: [
            .copy("Assets/Shaders")
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
            .product(name: "Subprocess", package: "swift-subprocess"),
            .product(
                name: "WebGPU",
                package: "swift-webgpu",
                condition: .when(traits: [
                    .wgpuTrait
                ])
            ),
        ],
        resources: [
            .copy("Assets/Shaders")
        ],
        swiftSettings: swiftSettings,
        plugins: {
           if isWGPUEnabled {
                return ["WebGPUBuildPlugin"]
           }
           return []
        }()
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
            "AdaCorePipelines",
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
            "AdaCorePipelines",
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
            "AdaRender",
            "AdaCorePipelines"
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
            "AdaRender",
            "AdaCorePipelines"
        ],
        resources: [
            .copy("Assets")
        ],
        swiftSettings: swiftSettings
    ),
]

targets.append(
    .plugin(
        name: "WebGPUBuildPlugin",
        capability: .buildTool(),
        dependencies: []
    )
)

// MARK: Build Plugins
if isWGPUEnabled {

    targets.append(
        .plugin(
            name: "WebGPUTintPlugin",
            capability: .command(
                intent: .custom(verb: "build-tint", description: "Build Tint compiler from Dawn repository"),
                permissions: [
                    .allowNetworkConnections(scope: .all(), reason: "Download dawn from github")
                ]
            ),
            dependencies: []
        )
    )
}

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

    // Box2d

    .target(
        name: "box2d",
        exclude: [
            "shared",
            "docs",
            "samples",
            "test",
            "benchmark",
            "extern",
            "build.bat",
            "build.sh",
            "build_emscripten.sh",
            "CMakeLists.txt",
            "deploy_docs.sh",
            "LICENSE"
        ],
        publicHeadersPath: "include",
        cSettings: [
            .unsafeFlags(["-w"])
        ]
    ),

    // GLSLang & SPIRV

    .adaTarget(
        name: "SPIRVCompiler",
        dependencies: [
            "glslang"
        ],
        publicHeadersPath: ".",
        linkerSettings: [
            .linkedLibrary("m", .when(platforms: [.linux]))
        ]
    ),
    .target(
        name: "glslang",
        sources: {
            var glslangSources: [String] = [
                "glslang/MachineIndependent/attribute.cpp",
                "glslang/MachineIndependent/Constant.cpp",
                "glslang/MachineIndependent/glslang_tab.cpp",
                "glslang/MachineIndependent/InfoSink.cpp",
                "glslang/MachineIndependent/Initialize.cpp",
                "glslang/MachineIndependent/Intermediate.cpp",
                "glslang/MachineIndependent/intermOut.cpp",
                "glslang/MachineIndependent/IntermTraverse.cpp",
                "glslang/MachineIndependent/iomapper.cpp",
                "glslang/MachineIndependent/limits.cpp",
                "glslang/MachineIndependent/linkValidate.cpp",
                "glslang/MachineIndependent/parseConst.cpp",
                "glslang/MachineIndependent/ParseContextBase.cpp",
                "glslang/MachineIndependent/ParseHelper.cpp",
                "glslang/MachineIndependent/PoolAlloc.cpp",
                "glslang/MachineIndependent/preprocessor/PpAtom.cpp",
                "glslang/MachineIndependent/preprocessor/PpContext.cpp",
                "glslang/MachineIndependent/preprocessor/Pp.cpp",
                "glslang/MachineIndependent/preprocessor/PpScanner.cpp",
                "glslang/MachineIndependent/preprocessor/PpTokens.cpp",
                "glslang/MachineIndependent/propagateNoContraction.cpp",
                "glslang/MachineIndependent/reflection.cpp",
                "glslang/MachineIndependent/RemoveTree.cpp",
                "glslang/MachineIndependent/Scan.cpp",
                "glslang/MachineIndependent/ShaderLang.cpp",
                "glslang/MachineIndependent/SpirvIntrinsics.cpp",
                "glslang/MachineIndependent/SymbolTable.cpp",
                "glslang/MachineIndependent/Versions.cpp",
                "glslang/GenericCodeGen/CodeGen.cpp",
                "glslang/GenericCodeGen/Link.cpp",
                "OGLCompilersDLL/InitializeDll.cpp",
                "SPIRV/disassemble.cpp",
                "SPIRV/doc.cpp",
                "SPIRV/GlslangToSpv.cpp",
                "SPIRV/InReadableOrder.cpp",
                "SPIRV/Logger.cpp",
                "SPIRV/SpvBuilder.cpp",
                "SPIRV/SpvPostProcess.cpp",
                "SPIRV/SPVRemapper.cpp",
                "SPIRV/SpvTools.cpp"
            ]

            #if os(Windows)
            glslangSources.append("glslang/OSDependent/Windows/ossource.cpp")
            #endif

            #if os(Linux) || os(android) || os(macOS) || os(iOS) || os(tvOS) || os(visionOS) || os(watchOS)
            glslangSources.append("glslang/OSDependent/Unix/ossource.cpp")
            #endif

            return glslangSources
        }(),
        publicHeadersPath: ".",
        cxxSettings: [
            .define("ENABLE_OPT", to: "0"),
            .unsafeFlags(["-w"])
        ]
    ),
    .target(
        name: "SPIRV-Cross",
        exclude: ["CMakeLists.txt",
                  "CODE_OF_CONDUCT.adoc",
                  "LICENSE",
                  "LICENSES",
                  "Makefile",
                  "README.md",
                  "appveyor.yml",
                  "build_glslang_spirv_tools.sh",
                  "checkout_glslang_spirv_tools.sh",
                  "format_all.sh",
                  "gn",
                  "pkg-config"
                 ],
        sources: ["spirv_cfg.cpp",
                  "spirv_cpp.cpp",
                  "spirv_cross.cpp",
                  "spirv_cross_c.cpp",
                  "spirv_cross_parsed_ir.cpp",
                  "spirv_cross_util.cpp",
                  "spirv_glsl.cpp",
                  "spirv_hlsl.cpp",
                  "spirv_msl.cpp",
                  "spirv_parser.cpp",
                  "spirv_reflect.cpp"],
        publicHeadersPath: "include",
        cxxSettings: [
            .define("SPIRV_CROSS_C_API_CPP", to: "1"),
            .define("SPIRV_CROSS_C_API_GLSL", to: "1"),
            .define("SPIRV_CROSS_C_API_HLSL", to: "1"),
            .define("SPIRV_CROSS_C_API_MSL", to: "1"),
            .define("SPIRV_CROSS_C_API_REFLECT", to: "1"),
            .unsafeFlags(["-w"])
        ]
    ),

    // LibPNG

    .target(
        name: "libpng",
        dependencies: [
            .product(name: "ZLib", package: "zlib"),
        ],
        sources: [
            "libpng/png.c",
            "libpng/pngerror.c",
            "libpng/pngget.c",
            "libpng/pngmem.c",
            "libpng/pngpread.c",
            "libpng/pngread.c",
            "libpng/pngrio.c",
            "libpng/pngrtran.c",
            "libpng/pngrutil.c",
            "libpng/pngset.c",
            "libpng/pngtrans.c",
            "libpng/pngwio.c",
            "libpng/pngwrite.c",
            "libpng/pngwtran.c",
            "libpng/pngwutil.c",
            "libpng/arm/arm_init.c",
            "libpng/arm/filter_neon_intrinsics.c",
            "libpng/arm/palette_neon_intrinsics.c",
        ],
        publicHeadersPath: "libpng/include",
        cSettings: [
            .define("PNG_ARM_NEON_OPT", to: {
#if (arch(arm64) || arch(arm))
                return "2"
#else
                return "0"
#endif
            }()),
            .unsafeFlags(["-w"])
        ]
    ),
    .target(
        name: "miniaudio",
        sources: ["miniaudio.c"],
        publicHeadersPath: "include",
        cSettings: [
            .unsafeFlags(["-w"])
        ],
        linkerSettings: [
            .linkedFramework("AVFoundation", .when(platforms: [.iOS]))
        ]
    ),

    // MSDF

    .adaTarget(
        name: "AtlasFontGenerator",
        dependencies: [
            "MSDFAtlasGen"
        ],
        publicHeadersPath: "include"
    ),
    .target(
        name: "MSDFGen",
        dependencies: [
            "freetype",
            "tinyxml"
        ],
        path: "Sources/msdf-atlas-gen/msdfgen",
        publicHeadersPath: ".",
        cxxSettings: [
            .define("MSDFGEN_USE_CPP11"),
            .headerSearchPath(".."),
            .unsafeFlags(["-w"])
        ]
    ),
    .target(
        name: "MSDFAtlasGen",
        dependencies: [
            "MSDFGen"
        ],
        path: "Sources/msdf-atlas-gen/msdf-atlas-gen",
        publicHeadersPath: ".",
        cxxSettings: [
            .define("_CRT_SECURE_NO_WARNINGS"),
            .headerSearchPath(".."),
            .unsafeFlags(["-w"])
        ]
    ),
    .target(
        name: "freetype",
        path: "Sources/msdf-atlas-gen/freetype",
        sources: [
            "src/autofit/autofit.c",
            "src/base/ftbase.c",
            "src/base/ftbbox.c",
            "src/base/ftbdf.c",
            "src/base/ftbitmap.c",
            "src/base/ftcid.c",
            "src/base/ftdebug.c",
            "src/base/ftfstype.c",
            "src/base/ftgasp.c",
            "src/base/ftglyph.c",
            "src/base/ftgxval.c",
            "src/base/ftinit.c",
            "src/base/ftmm.c",
            "src/base/ftotval.c",
            "src/base/ftpatent.c",
            "src/base/ftpfr.c",
            "src/base/ftstroke.c",
            "src/base/ftsynth.c",
            "src/base/ftsystem.c",
            "src/base/fttype1.c",
            "src/base/ftwinfnt.c",
            "src/bdf/bdf.c",
            "src/bzip2/ftbzip2.c",
            "src/cache/ftcache.c",
            "src/cff/cff.c",
            "src/cid/type1cid.c",
            "src/gzip/ftgzip.c",
            "src/lzw/ftlzw.c",
            "src/pcf/pcf.c",
            "src/pfr/pfr.c",
            "src/psaux/psaux.c",
            "src/pshinter/pshinter.c",
            "src/psnames/psnames.c",
            "src/raster/raster.c",
            "src/sdf/sdf.c",
            "src/sfnt/sfnt.c",
            "src/smooth/smooth.c",
            "src/truetype/truetype.c",
            "src/type1/type1.c",
            "src/type42/type42.c",
            "src/winfonts/winfnt.c"
        ],
        publicHeadersPath: "include",
        cSettings: [
            .define("FT2_BUILD_LIBRARY"),
            .define("_CRT_SECURE_NO_WARNINGS"),
            .define("_CRT_NONSTDC_NO_WARNINGS"),
            .unsafeFlags(["-w"])
        ]
    ),
    .target(
        name: "tinyxml",
        path: "Sources/msdf-atlas-gen/tinyxml",
        publicHeadersPath: ".",
        cSettings: [
            .unsafeFlags(["-w"])
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
    traits: [
        .trait(
            name: .wgpuTrait,
            description: "Enable WebGPU support"
        )
    ],
    dependencies: [],
    targets: targets,
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx17
)

package.dependencies += [
    .package(url: "https://github.com/apple/swift-collections", from: "1.3.0"),
    .package(url: "https://github.com/apple/swift-log", from: "1.8.0"),
    .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
    .package(url: "https://github.com/apple/swift-atomics", from: "1.3.0"),
    .package(url: "https://github.com/the-swift-collective/zlib.git", from: "1.3.2"),
    .package(url: "https://github.com/swiftlang/swift-subprocess.git", branch: "0.2.1"),
    // TODO: SpectralDragon packages should move to AdaEngine
    .package(url: "https://github.com/SpectralDragon/Yams.git", revision: "fb676da"),
    .package(
        url: "https://github.com/SpectralDragon/swift-webgpu",
        branch: "update_bindings"
    ),
    // Plugins
    .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.5"),
    .package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0"),
    .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins", from: "0.62.1"),
]

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
            dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ] + dependencies,
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
            path: "Demos/\(path)/",
            sources: [
                "\(name).swift"
            ],
            resources: [
                .copy("../Resources/")
            ],
            packageAccess: false
        )
    }
}

// MARK: - Examples

let examplesTargets: [Target] = [
    // MARK: 2d
    .exampleTarget(name: "BunniesStressExample", path: "2d"),
    .exampleTarget(name: "TransformEntChildrenExample", path: "2d"),
    .exampleTarget(name: "CustomMaterialExample", path: "2d"),
    .exampleTarget(name: "TransparencyExample", path: "2d"),
    .exampleTarget(name: "ManySpritesExample", path: "2d"),
    .exampleTarget(name: "Text2dExample", path: "2d"),
    .exampleTarget(name: "SpriteExample", path: "2d"),
    .exampleTarget(name: "WGSLExample", path: "2d"),

    // MARK: Input
    .exampleTarget(name: "GamepadExample", path: "Input"),

    // MARK: Scene
    .exampleTarget(name: "LoadSceneExample", path: "Scene"),
    .exampleTarget(name: "LdtkTilemapExample", path: "Scene"),
    .exampleTarget(name: "CustomTileMapExample", path: "Scene"),
    .exampleTarget(name: "ScriptableComponentExample", path: "Scene"),

    // MARK: Games
    .exampleTarget(name: "SnowmanAttacksExample", path: "Games"),

    // MARK: UI
    .exampleTarget(name: "UITestSceneExample", path: "UI"),
    .exampleTarget(name: "AnimatedTextRendererExample", path: "UI"),
    .exampleTarget(name: "ButtonExample", path: "UI"),

    // MARK: Example
    .exampleTarget(name: "SimpleCollideEventExample", path: "Events"),
]

package.targets.append(contentsOf: examplesTargets)

// MARK:  Examples -

// MARK: - Traits

var defaultTraits: Set<String> = []

if isWGPUEnabled {
    defaultTraits.insert(.wgpuTrait)
}

package.traits.insert(
    .default(enabledTraits: defaultTraits)
)
