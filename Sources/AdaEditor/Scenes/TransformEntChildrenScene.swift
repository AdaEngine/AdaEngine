//
//  TransformEntChildrenScene.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

class TransformEntChildrenScene {

    let characterAtlas: TextureAtlas

    init() {
        let charactersTiles = try! ResourceManager.loadSync("Assets/characters_packed.png", from: Bundle.editor) as Image
        self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
    }

    @MainActor
    func makeScene() async throws -> Scene {
        let scene = Scene()
        scene.debugOptions = [.showPhysicsShapes]

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        scene.addEntity(cameraEntity)

        let parent = Entity(name: "parent")
        parent.components += Transform(scale: Vector3(0.5), position: [0, 0, 0])
        parent.components += SpriteComponent(texture: characterAtlas[0, 0])
        parent.components += ParentComponent()
        parent.components += Collision2DComponent(
            shapes: [.generateBox()],
            mode: .trigger
        )

        let child = Entity(name: "child")
        child.components += Transform(scale: Vector3(0.4), position: [0.5, -0.5, 0])
        child.components += SpriteComponent(texture: characterAtlas[0, 1])
        child.components += Collision2DComponent(
            shapes: [.generateBox(width: 0.4, height: 0.4)],
            mode: .trigger
        )

        parent.addChild(child)

        scene.addEntity(parent)
        scene.addEntity(child)

        scene.addSystem(ParentMovementSystem.self)

        return scene
    }

}

@Component
struct ParentComponent {}

class ParentMovementSystem: System {

    static let query = EntityQuery(where: .has(ParentComponent.self))

    var time: TimeInterval = 0

    required init(scene: Scene) { }

    func update(context: UpdateContext) async {

        time += context.deltaTime

        context.scene.performQuery(Self.query).forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.x = Math.sin(time) * 1
            entity.components += transform
        }
    }
}
