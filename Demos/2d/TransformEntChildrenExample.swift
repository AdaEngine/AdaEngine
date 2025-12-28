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
        DefaultAppWindow()
            .addPlugins(
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
        app.main.spawn(bundle: OrthographicCameraBundle(camera: camera))

        let parent = app.main.spawn("parent") {
            Transform(scale: Vector3(2), position: [0, 0, 0])
            Sprite(texture: characterAtlas[0, 0], size: Size(width: 56, height: 56))
            ParentComponent()
        }

        let child = app.main.spawn("child") {
            Transform(scale: Vector3(2), position: [56, -56, 0])
            Sprite(texture: characterAtlas[0, 1], size: Size(width: 24, height: 24))
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

    @Res<ElapsedTime>
    private var time

    init(world: World) { }

    func update(context: UpdateContext) async {
        parents.forEach { transform in
            transform.position.x = Float(Math.sin(time.elapsedTime)) * 100
        }
    }
}
