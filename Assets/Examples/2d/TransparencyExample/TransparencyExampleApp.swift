//
//  TransparencyExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 10.12.2025.
//

import AdaEngine

@main
struct TransparencyExampleApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                TransparencyExamplePlugin()
            )
            .windowMode(.windowed)
    }
}

struct TransparencyExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.main.spawn(bundle: Camera2D())
        let texture = try! AssetsManager.loadSync(Texture2D.self, at: "Resources/dog.png", from: .module)

        let charactersTiles = try! AssetsManager.loadSync(
            Image.self,
            at: "Resources/characters_packed.png",
            from: Bundle.module
        )

        let characterAtlas = TextureAtlas(
            from: charactersTiles.asset!, size: [20, 23], margin: [4, 1])

        app.spawn("Red") {
            SpriteComponent(
                texture: texture,
                tintColor: Color.red.opacity(0.3)
            )
            Transform(position: Vector3(-0.5, 0, 0))
        }
        app.spawn("Blue") {
            SpriteComponent(
                texture: texture,
                tintColor: Color.blue.opacity(0.3)
            )
            Transform(position: Vector3(0, 0, 0.1))
        }
        app.spawn("Yellow") {
            SpriteComponent(
                texture: texture,
                tintColor: Color.yellow.opacity(0.3)
            )
            Transform(position: Vector3(0.5, 0, 0.2))
        }

        app.spawn("Sprite") {
            SpriteComponent(
                texture: characterAtlas[0, 0]
            )
            Transform(position: Vector3(0, 0.5, 0))
        }
    }
}
