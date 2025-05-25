//
//  TransformEntChildrenScene.swift
//
//
//  Created by v.prusakov on 5/4/24.
//

import AdaEngine

final class TransformEntChildrenScene: Scene, @unchecked Sendable {

    private var characterAtlas: TextureAtlas!

    override func sceneDidMove(to view: SceneView) {
        let charactersTiles = try! AssetsManager.loadSync(
            Image.self, 
            at: "Assets/characters_packed.png", 
            from: Bundle.editor
        ).asset
        self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])

        self.debugOptions = [.showPhysicsShapes]

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        self.world.addEntity(cameraEntity)

        let parent = Entity(name: "parent") {
            Transform(scale: Vector3(0.5), position: [0, 0, 0])
            SpriteComponent(texture: characterAtlas[0, 0])
            ParentComponent()

            Collision2DComponent(
                shapes: [.generateBox()],
                mode: .trigger
            )
        }

        let child = Entity(name: "child") {
            Transform(scale: Vector3(0.4), position: [0.5, -0.5, 0])
            SpriteComponent(texture: characterAtlas[0, 1])
            Collision2DComponent(
                shapes: [.generateBox(width: 0.4, height: 0.4)],
                mode: .trigger
            )
        }

        parent.addChild(child)

        self.world.addEntity(parent)
        self.world.addEntity(child)

        self.world.addSystem(ParentMovementSystem.self)
    }

}

@Component
struct ParentComponent {}

class ParentMovementSystem: System {

    static let query = EntityQuery(where: .has(ParentComponent.self))

    var time: TimeInterval = 0

    required init(world: World) { }

    func update(context: UpdateContext) {
        time += context.deltaTime
        context.world.performQuery(Self.query).forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.x = Math.sin(time) * 1
            entity.components += transform
        }
    }
}
