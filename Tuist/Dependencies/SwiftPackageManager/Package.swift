// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "PackageName",
    dependencies: [
        .package(url: "https://github.com/SwiftGL/Math", .upToNextMajor(from: "3.0.0")),
        .package(url: "https://github.com/troughton/Cstb", .upToNextMajor(from: "1.0.5")),
        .package(url: "https://github.com/apple/swift-collections", .upToNextMajor(from: "1.0.1")),
    ]
)