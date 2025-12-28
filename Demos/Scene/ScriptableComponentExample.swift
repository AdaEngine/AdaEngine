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

        app.spawn("Text") {
            ScriptableComponents(scripts: [
                GUIScriptableComponent()
            ])
        }
    }
}

final class PlayerScriptableComponent: ScriptableObject, @unchecked Sendable {

    @RequiredComponent
    private var sprite: Sprite

    private let speed: Float = 200

    override func update(_ deltaTime: TimeInterval) {
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
    }

    override func physicsUpdate(_ deltaTime: TimeInterval) {
        if input.isKeyPressed(.space) {
            sprite.tintColor = .random()
        }
    }
}

final class GUIScriptableComponent: ScriptableObject, @unchecked Sendable {

    lazy var attributedText: AttributedText = {
        var container = TextAttributeContainer()
        container.font = .system(size: 0.5)
        container.foregroundColor = .mint
        return AttributedText("Hi AdaEngine", attributes: container)
    }()

    var position: Vector2 = .zero
    let speed: Float = 200

    override func update(_ deltaTime: TimeInterval) {
        if input.isKeyPressed(.w) {
            position.y += speed * deltaTime
        }

        if input.isKeyPressed(.s) {
            position.y -= speed * deltaTime
        }

        if input.isKeyPressed(.a) {
            position.x -= speed * deltaTime
        }

        if input.isKeyPressed(.d) {
            position.x += speed * deltaTime
        }
    }

    override func updateGUI(_ deltaTime: TimeInterval, context: UIGraphicsContext) {
        let rect = Rect(x: 300, y: 500, width: 200, height: 100)
        context.drawRect(rect, color: .yellow)
        context.drawText(attributedText, in: rect)
    }
}
