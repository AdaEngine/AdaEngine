//
//  Lighting2DExample.swift
//  AdaEngine
//

import AdaEngine

@main
struct Lighting2DExampleApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(Lighting2DExamplePlugin())
            .windowMode(.windowed)
            .windowTitle("2D Lighting Example")
    }
}

private struct Lighting2DExamplePlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        let white = AssetHandle(Texture2D.whiteTexture)

        app.spawn {
            Sprite(texture: white, tintColor: Color(red: 0.12, green: 0.14, blue: 0.18), size: Size(width: 900, height: 700))
            Transform(position: Vector3(0, 0, -10))
        }

        app.spawn {
            Sprite(texture: white, tintColor: .yellow.opacity(0.95), size: Size(width: 64, height: 96))
            Transform(position: Vector3(-160, -70, 0))
        }

        app.spawn {
            Sprite(
                texture: white,
                tintColor: Color(red: 0.32, green: 0.36, blue: 0.44),
                size: Size(width: 88, height: 44)
            )
            LightOccluder2D(
                points: [
                    Vector2(-44, -22),
                    Vector2(44, -22),
                    Vector2(44, 22),
                    Vector2(-44, 22),
                ]
            )
            Transform(position: Vector3(50, 20, 1))
        }

        app.spawn {
            Light2D(
                kind: .point,
                color: Color(red: 1, green: 0.85, blue: 0.6),
                energy: 2,
                radius: 360,
                castsShadows: true
            )
            Transform(position: Vector3(-140, 100, 5))
        }

        app.spawn {
            Light2D(
                kind: .directional,
                color: Color(red: 0.35, green: 0.45, blue: 0.9),
                energy: 0.18,
                direction: Vector2(0.4, -0.9),
                radius: 0,
                castsShadows: false
            )
            Transform(position: Vector3(0, 0, 4))
        }

        let camera = app.main.spawn(bundle: Camera2D())
        camera.components += LightModulate2D(color: Color(red: 0.14, green: 0.16, blue: 0.22))
    }
}
