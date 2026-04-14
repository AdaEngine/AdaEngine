//
//  KeyframeSpritesExample.swift
//  AdaEngine
//

import AdaEngine

@main
struct KeyframeSpritesExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                KeyframeSpritesExamplePlugin()
            )
            .windowMode(.windowed)
            .windowTitle("Keyframe Sprites Example")
    }
}

struct KeyframeSpritesExamplePlugin: Plugin {
    func setup(in app: AppWorlds) {
        let texture = try! AssetsManager.loadSync(Texture2D.self, at: "Resources/dog.png", from: .module)

        app.main.spawn("HeroSprite") {
            Sprite(texture: texture, tintColor: .white)
            Transform(scale: [1, 1, 1], position: [0, 0, 0])
        }

        app.main.spawn("CompanionSprite") {
            Sprite(texture: texture, tintColor: .blue)
            Transform(scale: [0.7, 0.7, 1], position: [180, 0, 0])
        }

        app.main.spawn("DemoCamera", bundle: Camera2D())

        let idleClip = makeIdleClip()
        let burstClip = makeBurstClip()

        app.main.spawn("AnimationController") {
            KeyframeAnimator(clip: idleClip)
            AnimationStateController(
                state: "idle",
                clipsByState: [
                    "idle": idleClip,
                    "burst": burstClip,
                ]
            )
            KeyframeAnimationInputBindings(
                bindings: [
                    .init(keyCode: .num1, targetState: "idle"),
                    .init(keyCode: .num2, targetState: "burst"),
                ]
            )
        }
    }

    private func makeIdleClip() -> KeyframeClip {
        KeyframeClip(
            name: "idle",
            duration: 2,
            repeatMode: .loop,
            tracks: [
                .transformPosition(
                    .init(
                        targetEntityName: "HeroSprite",
                        keyframes: [
                            .init(time: 0, value: [0, 0, 0], curveToNext: .cubicInOut),
                            .init(time: 1, value: [0, 25, 0], curveToNext: .cubicInOut),
                            .init(time: 2, value: [0, 0, 0], curveToNext: .cubicInOut),
                        ]
                    )
                ),
                .transformRotation(
                    .init(
                        targetEntityName: "CompanionSprite",
                        keyframes: [
                            .init(time: 0, value: Quat(axis: [0, 0, 1], angle: -0.15), curveToNext: .linear),
                            .init(time: 1, value: Quat(axis: [0, 0, 1], angle: 0.15), curveToNext: .linear),
                            .init(time: 2, value: Quat(axis: [0, 0, 1], angle: -0.15), curveToNext: .linear),
                        ]
                    )
                ),
            ]
        )
    }

    private func makeBurstClip() -> KeyframeClip {
        KeyframeClip(
            name: "burst",
            duration: 1.5,
            repeatMode: .loop,
            tracks: [
                .transformScale(
                    .init(
                        targetEntityName: "HeroSprite",
                        keyframes: [
                            .init(time: 0, value: [1, 1, 1], curveToNext: .cubicInOut),
                            .init(time: 0.5, value: [1.35, 1.35, 1], curveToNext: .cubicInOut),
                            .init(time: 1.0, value: [0.9, 0.9, 1], curveToNext: .cubicInOut),
                            .init(time: 1.5, value: [1, 1, 1], curveToNext: .cubicInOut),
                        ]
                    )
                ),
                .transformPosition(
                    .init(
                        targetEntityName: "CompanionSprite",
                        keyframes: [
                            .init(time: 0, value: [180, 0, 0], curveToNext: .linear),
                            .init(time: 0.75, value: [-180, 0, 0], curveToNext: .linear),
                            .init(time: 1.5, value: [180, 0, 0], curveToNext: .linear),
                        ]
                    )
                ),
                .cameraOrthographicScale(
                    .init(
                        targetEntityName: "DemoCamera",
                        keyframes: [
                            .init(time: 0, value: 1, curveToNext: .cubicInOut),
                            .init(time: 0.75, value: 1.25, curveToNext: .cubicInOut),
                            .init(time: 1.5, value: 1, curveToNext: .cubicInOut),
                        ]
                    )
                ),
            ]
        )
    }
}
