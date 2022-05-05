//
//  Dependencies.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//


import ProjectDescription

let dependencies = Dependencies(
    swiftPackageManager: [
        .remote(
            url: "https://github.com/troughton/Cstb",
            requirement: .upToNextMajor(from: "1.0.5")
        ),
        .remote(
            url: "https://github.com/apple/swift-collections",
            requirement: .upToNextMajor(from: "1.0.1")
        ),
    ],
    platforms: [.macOS, .iOS]
)
