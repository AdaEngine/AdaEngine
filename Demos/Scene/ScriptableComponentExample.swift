//
//  ScriptableComponentExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 20.12.2025.
//

import AdaEngine

@main
struct ScriptableComponentExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                ScriptableComponentExamplePlugin()
            )
            .windowMode(.windowed)
    }
}

struct ScriptableComponentExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.spawn(bundle: Camera2D())

        app.spawn("Player") {
            Transform()
            ScriptableComponents(scripts: [
                PlayerScriptableComponent()
            ])
            Sprite(tintColor: .red, size: .init(width: 64, height: 64))
        }
    }
}

final class PlayerScriptableComponent: ScriptableObject, @unchecked Sendable {
    @RequiredComponent
    private var sprite: Sprite

    private let speed: Float = 200

    override func update(context: ScriptableObjectContext) {
        let deltaTime = context.deltaTime
        let input = context.input
        var transform = context.component(Transform.self) ?? Transform()
        if input.isKeyPressed(.w) {
            transform.position.y += speed * deltaTime
        }

        if input.isKeyPressed(.s) {
            transform.position.y -= speed * deltaTime
        }

        if input.isKeyPressed(.a) {
            transform.position.x -= speed * deltaTime
        }

        if input.isKeyPressed(.d) {
            transform.position.x += speed * deltaTime
        }
        context.setComponent(transform)
    }

    override func fixedUpdate(context: ScriptableObjectContext) {
        let input = context.input
        if input.isKeyPressed(.space) {
            sprite.tintColor = .random()
        }
    }
}
