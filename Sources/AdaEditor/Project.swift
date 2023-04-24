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
    organizationName: "AdaEngine",
    packages: [],
    settings: .editor,
    targets: [
        Target(
            name: "AdaEditor",
            platform: .macOS,
            product: .app,
            bundleId: .bundleIdentifier(name: "editor"),
            deploymentTarget: .macOS(targetVersion: "11.0"),
            infoPlist: .extendingDefault(with: [
                "NSMainStoryboardFile": .string(""),
            ]),
            sources: [
                .glob("**/*.swift", excluding: ["Project.swift"])
            ],
            resources: [
                .folderReference(path: "Assets")
            ],
            dependencies: [
                .project(target: "AdaEngine", path: "../AdaEngine")
            ],
            settings: .targetSettings(swiftFlags: [
                .define("MACOS"),
                .define("METAL"),
                .define("TUIST"),
                .experementalCXXInterop
            ])
        )
        // TODO: Add multiplatform target
//        Target(
//            name: "AdaEditor",
//            platform: .iOS,
//            product: .app,
//            bundleId: .bundleIdentifier(name: "editor"),
//            deploymentTarget: .iOS(targetVersion: "13.0", devices: [.ipad, .iphone, .mac]),
//            infoPlist: .extendingDefault(with: [
//                "UIMainStoryboardFile": .string("")
//            ]),
//            sources: [
//                .glob("**/*.swift", excluding: ["Project.swift"])
//            ],
//            resources: [
//                .folderReference(path: "Assets")
//            ],
//            dependencies: [
//                .project(target: "AdaEngine", path: "../AdaEngine")
//            ],
//            settings: .targetSettings(swiftFlags: [
//                .define("IOS"),
//                .define("METAL"),
//                .define("TUIST")
//            ])
//        )
    ],
    schemes: [
        Scheme(
            name: "AdaEditor",
            buildAction: .buildAction(targets: ["AdaEditor"]),
            runAction: RunAction.runAction(
                configuration: .debug,
                attachDebugger: true,
                executable: "AdaEditor",
                options: .options(
                    enableGPUFrameCaptureMode: .metal
                ),
                diagnosticsOptions: [
//                    .mainThreadChecker
                ]
            ),
            profileAction: .profileAction(
                configuration: .debug,
                executable: "AdaEditor"
            ),
            analyzeAction: .analyzeAction(configuration: .debug)
        )
    ]
)
