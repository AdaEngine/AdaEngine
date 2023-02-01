//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

#if (arch(arm64) || arch(arm))
let useNeon = true
#else
let useNeon = false
#endif

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
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ],
            headers: .headers(public: ["include/*.h"]),
            dependencies: [
                .sdk(name: "c++", type: .library)
            ],
            settings: .targetSettings(cFlags: [
                .define("PNG_ARM_NEON_OPT", to: useNeon ? "2" : "0")
            ])
        )
    ]
)
