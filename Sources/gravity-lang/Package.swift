// swift-tools-version: 6.0
import CompilerPluginSupport
import PackageDescription

// Runtime/compiler subset of the pinned upstream package; see UPSTREAM.md.
let package = Package(
    name: "Gravity",
    platforms: [.macOS(.v12), .iOS(.v16), .tvOS(.v16), .visionOS(.v1)],
    products: [
        .library(name: "Gravity", targets: ["Gravity"]),
        .library(name: "GravityAOT", targets: ["GravityAOT"]),
        .library(name: "CGravity", targets: ["CGravity"]),
    ],
    dependencies: [.package(url: "https://github.com/swiftlang/swift-syntax", from: "602.0.0")],
    targets: [
        .target(name: "GravityAOT", dependencies: ["CGravity"], path: "binding/GravityAOT"),
        .target(name: "Gravity", dependencies: ["CGravity", "GravitySwiftMacros"], path: "binding/GravitySwift"),
        .target(name: "CGravity", path: "src", exclude: ["cli"], publicHeadersPath: "."),
        .macro(
            name: "GravitySwiftMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
            ],
            path: "binding/GravitySwiftMacros"
        ),
    ],
    cLanguageStandard: .gnu99,
    cxxLanguageStandard: .gnucxx11
)
