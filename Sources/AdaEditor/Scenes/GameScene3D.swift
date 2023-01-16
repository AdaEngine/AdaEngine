//
//  GameScene3D.swift
//  AdaEditor
//
//  Created by v.prusakov on 8/11/22.
//

import AdaEngine

class GameScene3D {
    func makeScene() throws -> Scene {
        let scene = Scene(name: "3D")
        
//        scene.addSystem(EditorCameraSystem.self)
        
//        let camera = EditorCameraEntity()
//        camera.components[Camera.self]?.isPrimal = true
//        scene.addEntity(camera)
        
        var transform = Transform()
        transform.scale = [10, 10, 10]

        let untexturedEntity = Entity(name: "Background")
        untexturedEntity.components += SpriteComponent(tintColor: Color.blue)
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
        
        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        userEntity.components += camera
        scene.addEntity(userEntity)
        
//        let mesh = Mesh.generateBox(extent: [1, 1, 1], segments: [1, 1, 1])
        
//        let train = Entity(name: "Box")
//        train.components += ModelComponent(mesh: mesh)
//        scene.addEntity(train)
//
        return scene
    }
}

struct EntitiesCounterSystem: System {
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
    }
}

struct SpawnEntitySystem: System {
    
    let transform: Transform
    let characterAtlas: TextureAtlas
    
    init(scene: Scene) {
        self.transform = Transform(scale: Vector3(0.2))
        let charactersTiles = try! Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/characters_packed.png"))
        self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
    }
    
    func update(context: UpdateContext) {
        if Input.isMouseButtonPressed(.left) {
            for _ in 0..<100 {
                self.spawnEntity(in: context.scene)
            }
        }
    }
    
    private func spawnEntity(in scene: Scene) {
        let entity = Entity()
        entity.components += transform
        entity.components += SpriteComponent(texture: self.characterAtlas[0, 0])
        entity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: transform.scale.x, height: transform.scale.y)
            ],
            mass: 1
        )
        
        scene.addEntity(entity)
    }
}

class StressTestGameScene {
    
    let textureAtlas: TextureAtlas
    
    init() {
        do {
            let tiles = try Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/tiles_packed.png"))

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makeScene() throws -> Scene {
        let scene = Scene()
        scene.activeCamera.projection = .orthographic
        
        self.makeBackground(for: scene)
        self.makeWalls(for: scene)
        
        scene.addSystem(SpawnEntitySystem.self)
        scene.addSystem(EntitiesCounterSystem.self)
        
        return scene
    }
    
    private func makeBackground(for scene: Scene) {
        var transform = Transform()
        transform.scale = [10, 10, 10]

        let untexturedEntity = Entity(name: "Background")
        untexturedEntity.components += SpriteComponent(tintColor: Color(135/255, 206/255, 235/255, 1))
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
    }
    
    private func makeWalls(for scene: Scene) {
        var transform = Transform()
        transform.scale = [3, 0.19, 0.19]
        transform.position.y = -4.9

        let untexturedEntity = Entity(name: "Ground")
        untexturedEntity.components += SpriteComponent(tintColor: .brown)
        untexturedEntity.components += transform
        untexturedEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 1)
            ],
            mass: 0,
            mode: .static
        )

        scene.addEntity(untexturedEntity)
        
        transform.position.y = 4.9
        
        let topEntity = Entity(name: "Top")
        topEntity.components += SpriteComponent(tintColor: .brown)
        topEntity.components += transform
        topEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 1)
            ],
            mass: 0,
            mode: .static
        )
        
        scene.addEntity(topEntity)
        
        transform.scale = [0.19, 0.19, 0.19]
        transform.position.x = -0.3
        
        let leftEntity = Entity(name: "Left")
        leftEntity.components += SpriteComponent(tintColor: .brown)
        leftEntity.components += transform
        leftEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 1)
            ],
            mass: 0,
            mode: .static
        )
        
        scene.addEntity(leftEntity)
        
        transform.position.x = 1
        
        let rightEntity = Entity(name: "Right")
        rightEntity.components += SpriteComponent(tintColor: .brown)
        rightEntity.components += transform
        rightEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 1)
            ],
            mass: 0,
            mode: .static
        )
        
        scene.addEntity(rightEntity)
    }
    
}
