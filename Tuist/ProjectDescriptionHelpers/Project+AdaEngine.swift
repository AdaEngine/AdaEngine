//
//  Project+AdaEngine.swift
//  AdaEngineManifests
//
//  Created by v.prusakov on 5/2/22.
//

import ProjectDescription

//
//let project = Project(
//    name: "MyProject",
//    organizationName: "MyOrg",
//    targets: [
//        Target(
//            name: "App",
//            platform: .iOS,
//            product: .app,
//            bundleId: "io.tuist.App",
//            infoPlist: "Config/App-Info.plist",
//            sources: ["Sources/**"],
//            resources: [
//                "Resources/**",
//                .folderReference(path: "Stubs"),
//                .folderReference(path: "ODR", tags: ["odr_tag"])
//            ],
//            headers: Headers(
//                public: ["Sources/public/A/**", "Sources/public/B/**"],
//                private: "Sources/private/**",
//                project: ["Sources/project/A/**", "Sources/project/B/**"]
//            ),
//            dependencies: [
//                .project(target: "Framework1", path: "../Framework1"),
//                .project(target: "Framework2", path: "../Framework2")
//            ]
//        )
//    ],
//    schemes: [
//        Scheme(
//            name: "App-Debug",
//            shared: true,
//            buildAction: .buildAction(targets: ["App"]),
//            testAction: .targets(["AppTests"]),
//            runAction: .runAction(executable: "App")
//        ),
//        Scheme(
//            name: "App-Release",
//            shared: true,
//            buildAction: .buildAction(targets: ["App"]),
//            runAction: .runAction(executable: "App")
//        )
//    ],
//    additionalFiles: [
//        "Dangerfile.swift",
//        "Documentation/**",
//        .folderReference(path: "Website")
//    ]
//)

public extension Project {
    
    static func makeEditorProject() -> Project {
        Project(
            name: "AdaEngine",
            organizationName: "$(PRODUCT_BUNDLE_IDENTIFIER).editor",
            packages: [],
            settings: nil,
            targets: [
                Target(
                    name: "AdaEditor",
                    platform: .macOS,
                    product: .app,
                    bundleId: "$(PRODUCT_BUNDLE_IDENTIFIER).editor",
                    deploymentTarget: .macOS(targetVersion: "11.0"),
                    scripts: [],
                    dependencies: [
                        .project(target: "AdaEngine", path: "../AdaEngine")
                    ]
                )
            ]
        )
    }
}

extension Settings {
    var app: Settings {
        Settings.settings(base: ["PRODUCT_BUNDLE_IDENTIFIER": "dev.litecode.adaengine"])
    }
}
