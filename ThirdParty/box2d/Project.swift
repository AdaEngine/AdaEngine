//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 6/4/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let settings = Settings.settings(base: [
    "PRODUCT_BUNDLE_IDENTIFIER": "dev.litecode.adaengine",
    "CLANG_WARN_QUOTED_INCLUDE_IN_FRAMEWORK_HEADER": false
])

let project = Project(
    name: "box2d",
    settings: settings,
    targets: [
        Target(
            name: "box2d",
            platform: .macOS,
            product: .framework,
            productName: "box2d",
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).box2d",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: ["Sources/box2d/**"],
            headers: .headers(public: ["Sources/box2d/**/*.h"])
        )
    ]
)
