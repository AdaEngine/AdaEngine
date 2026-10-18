// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AdaStudioWeb",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "AdaEditorWeb", targets: ["AdaEditorWeb"])],
    dependencies: [
        .package(name: "AdaEngine", path: "../.."),
        .package(path: "../StudioCore"),
        // Match the engine's generated Swan bridges (newer JSKit changes the lowering ABI).
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", exact: "0.53.0")
    ],
    targets: [.executableTarget(
        name: "AdaEditorWeb",
        dependencies: [
            .product(name: "AdaEngine", package: "AdaEngine"),
            .product(name: "AdaScriptCompilerCore", package: "AdaEngine"),
            .product(name: "AdaStudioCore", package: "StudioCore"),
            .product(name: "JavaScriptKit", package: "JavaScriptKit", condition: .when(platforms: [.wasi]))
        ],
        resources: [.copy("Resources")],
        swiftSettings: [.define("WASM", .when(platforms: [.wasi])), .define("BROWSER", .when(platforms: [.wasi]))],
        linkerSettings: [.unsafeFlags(["-Xclang-linker", "-mexec-model=reactor", "-Xlinker", "--export-if-defined=main", "-Xlinker", "--export-if-defined=__main_argc_argv"], .when(platforms: [.wasi]))]
    )]
)
