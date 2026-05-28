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
        DefaultAppWindow()
            .addPlugins(
                TransparencyExamplePlugin()
            )
            .windowMode(.windowed)
    }
}

struct TransparencyExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.main.spawn(bundle: Camera2D())
        app.addSystem(SetupTransparencySystem.self, on: .startup)
    }
}

@System
func SetupTransparency(_ commands: Commands) async {
    let texture: AssetHandle<Texture2D>
    do {
        texture = try await AssetsManager.load(Texture2D.self, at: "Resources/dog.png", from: .module)
    } catch {
        print("Failed to load texture: \(error), using white texture")
        texture = AssetHandle(Texture2D.whiteTexture)
    }

    commands.spawn("Red") {
        Sprite(
            texture: texture,
            tintColor: Color.red.opacity(0.3)
        )
        Transform(position: Vector3(-256, 0, 0))
    }
    commands.spawn("Blue") {
        Sprite(
            texture: texture,
            tintColor: Color.blue.opacity(0.3)
        )
        Transform(position: Vector3(0, 0, 0.1))
    }
    commands.spawn("Yellow") {
        Sprite(
            texture: texture,
            tintColor: Color.yellow.opacity(0.3)
        )
        Transform(position: Vector3(256, 0, 0.2))
    }
}
