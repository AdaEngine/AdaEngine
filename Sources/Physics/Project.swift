//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let settings = Settings.settings(base: [
    "PRODUCT_BUNDLE_IDENTIFIER": "dev.litecode.adaengine",
    "OTHER_SWIFT_FLAGS": "-Xfrontend -enable-cxx-interop -Xcc -Wno-error=non-modular-include-in-framework-module"
])

let project = Project(
    name: "Physics",
    settings: settings,
    targets: [
        Target(
            name: "Physics",
            platform: .macOS,
            product: .framework,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).physics",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ],
            dependencies: [
                .project(
                    target: "box2d",
                    path: .relativeToRoot("ThirdParty/box2d")
                ),
                .project(
                    target: "Math",
                    path: .relativeToRoot("Sources/Math")
                ),
                .sdk(name: "c++", type: .library)
            ]
        )
    ]
)

