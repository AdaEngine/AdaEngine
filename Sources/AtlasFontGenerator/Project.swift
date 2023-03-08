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
    name: "AtlasFontGenerator",
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
                .glob("**/*", excluding: ["Project.swift"])
            ],
            headers: .headers(public: ["*.h"]),
            dependencies: [
                .sdk(name: "c++", type: .library),
                .external(name: "msdf-atlas-gen")
            ]
        )
    ]
)
