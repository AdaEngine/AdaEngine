//
//  AdaEditorApp.swift
//  AdaEngine
//
//  Created by v.prusakov on 8/10/21.
//

import AdaEngine
import Logging

@main
struct AdaEditorApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                TestPlugin(),
//                BunnyExample()
            )
            .windowMode(.windowed)
            .windowTitle("AdaEngine")
    }
}

struct TestPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        for index in 0..<150_000 {
            app.main.spawn("Entity \(index)") {
                Transform()
                    .setPosition([0, Float(index), 0])

//                if index % 2 == 0 {
                    NoFrustumCulling()
//                }
            }
        }

        let query = app.main.performQuery(FilterQuery<Transform, NoFrustumCulling, NoFilter>())
        Task {
            print("Create query")
            for (transform, _) in query {
                print(transform.position)
            }

            print("Finished")
        }
    }
}

public extension Foundation.Bundle {
    static var editor: Foundation.Bundle {
#if SWIFT_PACKAGE && !BAZEL_BUILD
        return Foundation.Bundle.module
#else
        return Foundation.Bundle(for: BundleToken.self)
#endif
    }
}

#if !SWIFT_PACKAGE || BAZEL_BUILD
class BundleToken {}
#endif
