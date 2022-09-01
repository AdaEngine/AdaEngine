//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "libpng",
    settings: .adaEngine,
    targets: [
        Target(
            name: "libpng",
            platform: .macOS,
            product: .framework,
            productName: "libpng",
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).libpng",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: ["Sources/libpng/**"],
            headers: .headers(public: ["Sources/libpng/*.h"]),
            dependencies: [
                .sdk(name: "c++", type: .library)
            ]
        )
    ]
)
