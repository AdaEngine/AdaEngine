//
//  Project.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription
import ProjectDescriptionHelpers

let project = Project(
    name: "AdaEditor",
    organizationName: "$(PRODUCT_BUNDLE_IDENTIFIER).editor",
    packages: [],
    settings: .adaEngine,
    targets: [
        Target(
            name: "AdaEditor",
            platform: .macOS,
            product: .app,
            bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).editor",
            deploymentTarget: .macOS(targetVersion: "11.0"),
            infoPlist: .extendingDefault(with: [
                "NSMainStoryboardFile": .string(""),
            ]),
            sources: [
                .glob("**/*", excluding: ["Project.swift"])
            ],
            resources: [ResourceFileElement.folderReference(path: "Assets", tags: [])],
            dependencies: [
                .project(target: "AdaEngine", path: "../AdaEngine")
            ]
        )
    ]
)
