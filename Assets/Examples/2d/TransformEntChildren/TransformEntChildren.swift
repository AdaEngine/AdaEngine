//
//  TransformEntChildrenScene.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

@main
struct TransformEntChildrenApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                TransformEntChildrenPlugin()
            )
            .windowMode(.windowed)
    }
}

struct TransformEntChildrenPlugin: Plugin {

    @Local private var characterAtlas: TextureAtlas!

    func setup(in app: borrowing AppWorlds) {
        let charactersTiles = try! AssetsManager.loadSync(
            Image.self,
            at: "Resources/characters_packed.png",
            from: Bundle.module
        ).asset!
        self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])

        var camera = Camera()
        camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        camera.clearFlags = .solid
        camera.orthographicScale = 1.5
        app.main.spawn(bundle: OrthographicCameraBundle(camera: camera))

        let parent = app.main.spawn("parent") {
            Transform(scale: Vector3(0.5), position: [0, 0, 0])
            SpriteComponent(texture: characterAtlas[0, 0])
            ParentComponent()

            Collision2DComponent(
                shapes: [.generateBox()],
                mode: .trigger
            )
        }

        let child = app.main.spawn("child") {
            Transform(scale: Vector3(0.4), position: [0.5, -0.5, 0])
            SpriteComponent(texture: characterAtlas[0, 1])
            Collision2DComponent(
                shapes: [.generateBox(width: 0.4, height: 0.4)],
                mode: .trigger
            )
        }

        parent.addChild(child)

        app.main.addSystem(ParentMovementSystem.self)
    }
}

@Component
struct ParentComponent {}

@PlainSystem
struct ParentMovementSystem {

    @FilterQuery<Ref<Transform>, With<ParentComponent>>
    private var parents

    @Res<DeltaTime>
    private var deltaTime

    @Local var time: TimeInterval = 0

    init(world: World) { }

    func update(context: UpdateContext) async {
        time += deltaTime.deltaTime
        parents.forEach { transform in
            transform.position.x = Float(Math.sin(time)) * 1
        }
    }
}
