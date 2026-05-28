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
        DefaultAppWindow()
            .addPlugins(
                SpriteExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("Sprite Example")
    }
}

struct SpriteExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.main.spawn(bundle: Camera2D())
        app.addSystem(SetupSpriteSystem.self, on: .startup)
    }
}

@System
func SetupSprite(_ commands: Commands) async {
    let texture: AssetHandle<Texture2D>
    do {
        texture = try await AssetsManager.load(Texture2D.self, at: "Resources/dog.png", from: .module)
    } catch {
        print("Failed to load texture: \(error), using white texture")
        texture = AssetHandle(Texture2D.whiteTexture)
    }

    commands.spawn {
        Sprite(texture: texture)
        Transform()
    }
}
