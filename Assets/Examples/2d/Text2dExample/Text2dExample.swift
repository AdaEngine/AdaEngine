//
//  Text2dExample.swift
//  AdaEngine
//
//  Created by Vladislav Prusakov on 19.12.2025.
//

import AdaEngine

@main
struct Text2dExample: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                Text2dPlugin(),
            )
            .windowMode(.windowed)
    }
}

struct Text2dPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app.spawn(bundle: Camera2D())

        var textAttributes = TextAttributeContainer()
        textAttributes.foregroundColor = .red
        textAttributes.font = .system(size: 56)

        app.spawn(
            "AnimateTranslationText",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("Translation", attributes: textAttributes)
                )
            )
            .extend {
                AnimateTranslation()
            }
        )

        app.spawn(
            "AnimateRotationText",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("Rotation", attributes: textAttributes)
                ),
                transform: Transform()
            )
            .extend {
                AnimateRotation()
            }
        )

        app.spawn(
            "AnimateScaleText",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("Scale", attributes: textAttributes)
                ),
                transform: Transform(position: [400, 0, 0])
            )
            .extend {
                AnimateScale()
            }
        )

        app
            .addSystem(AnimateScaleTextSystem.self)
            .addSystem(AnimateRotationTextSystem.self)
            .addSystem(AnimateTranslationTextSystem.self)
    }
}

@Component
struct AnimateTranslation {}

@Component
struct AnimateRotation {}

@Component
struct AnimateScale {}


@System
func AnimateTranslationText(
    _ query: FilterQuery<Ref<Transform>, With<AnimateTranslation>>,
    _ time: Res<ElapsedTime>
) {
    query.forEach { transform in
        transform.position.x = 100 * Math.sin(time.value) - 600
        transform.position.y = 100 * Math.cos(time.value)
    }
}

@System
func AnimateRotationText(
    _ query: FilterQuery<Ref<Transform>, With<AnimateRotation>>,
    _ time: Res<ElapsedTime>
) {
    query.forEach { transform in
        transform.rotation = Quat(axis: [0, 0, 1], angle: Math.cos(time.value))
    }
}

@System
func AnimateScaleText(
    _ query: FilterQuery<Ref<Transform>, With<AnimateScale>>,
    _ time: Res<ElapsedTime>
) {
    query.forEach { transform in
        let scale = (Math.sin(time.value) + 1.1) * 2.0
        transform.scale.x = scale
        transform.scale.y = scale
    }
}
