//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "SPIRVCompiler",
    packages: [
        .remote(
            url: "https://github.com/AdaEngine/glslang",
            requirement: .branch("main")
        )
    ],
    settings: .common,
    targets: [
        Target(
            name: "SPIRVCompiler",
            platform: .macOS,
            product: .framework,
            productName: "SPIRVCompiler",
            bundleId: .bundleIdentifier(name: "spirv-compiler"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("*.cpp", excluding: ["Project.swift"])
            ],
            headers: .headers(public: ["*.hpp"]),
            dependencies: [
                .sdk(name: "c++", type: .library),
                .package(product: "glslang")
            ],
            settings: .targetSettings(swiftFlags: [
                .experementalCXXInterop
            ])
        )
    ]
)
