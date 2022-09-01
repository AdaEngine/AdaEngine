//
//  Dependencies.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let spm = SwiftPackageManagerDependencies([
    .remote(
        url: "https://github.com/troughton/Cstb",
        requirement: .upToNextMajor(from: "1.0.5")
    ),
    .remote(
        url: "https://github.com/apple/swift-collections",
        requirement: .upToNextMajor(from: "1.0.1")
    ),
    .remote(
        url: "https://github.com/jpsim/Yams.git",
        requirement: .upToNextMajor(from: "5.0.1")
    )
], baseSettings: .adaEngine)

let dependencies = Dependencies(
    swiftPackageManager: spm,
    platforms: [.macOS]
)
