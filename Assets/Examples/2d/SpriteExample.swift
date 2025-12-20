//
//  SpriteExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 21.12.2025.
//

import AdaEngine

@main
struct SpriteExampleApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                SpriteExamplePlugin()
            )
            .windowMode(.windowed)
    }
}

struct SpriteExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        let texture = try! AssetsManager.loadSync(Texture2D.self, at: "Resources/dog.png", from: .module)
        app.spawn {
            Sprite(texture: texture)
            Transform()
        }
        app.main.spawn(bundle: Camera2D())
    }
}
