//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "AtlasFontGenerator",
    packages: [
        .remote(
            url: "https://github.com/AdaEngine/msdf-atlas-gen",
            requirement: .branch("master")
        )
    ],
    settings: .common,
    targets: [
        Target(
            name: "AtlasFontGenerator",
            platform: .macOS,
            product: .framework,
            productName: "AtlasFontGenerator",
            bundleId: .bundleIdentifier(name: "atlasfontgenerator"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("*.cpp", excluding: ["Project.swift"])
            ],
            headers: .headers(public: ["*.h"]),
            dependencies: [
                .sdk(name: "c++", type: .library),
                .package(product: "MSDFAtlasGen")
            ],
            settings: .targetSettings(swiftFlags: [
                .experementalCXXInterop
            ])
        )
    ]
)
