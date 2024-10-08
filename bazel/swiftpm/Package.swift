// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription
import Foundation
import CompilerPluginSupport

let package = Package(
    name: "AdaEngineDeps",
    dependencies: [
        // FIXME: If possible - move to local `vendors` folder
        .package(url: "https://github.com/apple/swift-collections", from: "1.1.1"),
        .package(url: "https://github.com/AdaEngine/box2d-swift", branch: "main"),
        .package(url: "https://github.com/apple/swift-log", from: "1.5.4")
    ],
    swiftLanguageVersions: [.v5],
    cLanguageStandard: .c17,
    cxxLanguageStandard: .cxx20
)