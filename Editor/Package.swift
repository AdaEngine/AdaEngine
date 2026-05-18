// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdaEditor",
    defaultLocalization: "en",
    platforms: [
        .iOS(.v18),
        .tvOS(.v18),
        .visionOS(.v2),
        .macOS(.v15),
    ],
    products: [
        .executable(
            name: "AdaEditor",
            targets: ["AdaEditor"]
        )
    ],
    dependencies: [
        .package(path: ".."),
        .package(url: "https://github.com/AdaEngine/AdaMCP", branch: "main")
    ],
    targets: [
        .executableTarget(
            name: "AdaEditor",
            dependencies: [
                .product(name: "AdaEngine", package: "AdaEngine"),
                .product(name: "Math", package: "AdaEngine"),
                .product(name: "AdaMCPCore", package: "AdaMCP"),
                .product(name: "AdaMCPServer", package: "AdaMCP"),
                .product(name: "AdaMCPPlugin", package: "AdaMCP")
            ],
            exclude: [
                "Platforms/iOS/Info.plist",
                "Platforms/macOS/Info.plist"
            ],
            resources: [
                .copy("Assets")
            ],
            swiftSettings: editorSwiftSettings
        ),
        .testTarget(
            name: "AdaEditorTests",
            dependencies: [
                "AdaEditor",
                .product(name: "AdaEngine", package: "AdaEngine"),
                .product(name: "Math", package: "AdaEngine")
            ],
            exclude: [
                "Fixtures"
            ]
        )
    ]
)

let editorSwiftSettings: [SwiftSetting] = [
    .define("MACOS", .when(platforms: [.macOS])),
    .define("WINDOWS", .when(platforms: [.windows])),
    .define("IOS", .when(platforms: [.iOS])),
    .define("TVOS", .when(platforms: [.tvOS])),
    .define("VISIONOS", .when(platforms: [.visionOS])),
    .define("ANDROID", .when(platforms: [.android])),
    .define("LINUX", .when(platforms: [.linux])),
    .define("DARWIN", .when(platforms: [.iOS, .macOS, .tvOS, .watchOS, .visionOS])),
    .define("METAL", .when(platforms: [.iOS, .macOS, .tvOS, .watchOS, .visionOS])),
    .define("ENABLE_DEBUG_DYLIB", .when(configuration: .debug)),
    .define("EDITOR_DEBUG", .when(configuration: .debug)),
    .define("EDITOR_MACOS", .when(platforms: [.macOS])),
    .define("EDITOR_WINDOWS", .when(platforms: [.windows])),
    .define("EDITOR_IOS", .when(platforms: [.iOS])),
    .define("EDITOR_TVOS", .when(platforms: [.tvOS])),
    .define("EDITOR_ANDROID", .when(platforms: [.android])),
    .define("EDITOR_LINUX", .when(platforms: [.linux])),
    .enableUpcomingFeature("MemberImportVisibility"),
    .strictMemorySafety(),
    .unsafeFlags(["-Xfrontend", "-validate-tbd-against-ir=none"]),
]
