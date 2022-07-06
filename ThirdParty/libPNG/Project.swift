//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "LibPNG",
    settings: .adaEngine,
    targets: [
        Target(
            name: "LibPNG",
            platform: .macOS,
            product: .framework,
            productName: "cpng",
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).libpng",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            headers: .allHeaders(from: "Sources/cpng/*", umbrella: "Sources/cpng/module.modulemap"),
            dependencies: [
                .sdk(name: "c++", type: .library)
            ]
        )
    ]
)
