//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "AdaBox2d",
    packages: [
        .remote(
            url: "https://github.com/AdaEngine/box2d-swift",
            requirement: .branch("main")
        )
    ],
    settings: .common,
    targets: [
        Target(
            name: "AdaBox2d",
            platform: .macOS,
            product: .framework,
            productName: "AdaBox2d",
            bundleId: .bundleIdentifier(name: "adabox2d"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("*.cpp", excluding: ["Project.swift"])
            ],
            headers: .headers(public: ["*.h"]),
            dependencies: [
                .sdk(name: "c++", type: .library),
                .package(product: "box2d")
            ],
            settings: .targetSettings(swiftFlags: [
                .experementalCXXInterop
            ])
        )
    ]
)
