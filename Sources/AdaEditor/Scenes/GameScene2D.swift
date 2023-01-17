//
//  GameScene2D.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

struct PlayerMovementSystem: System {
    
    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(PhysicsBody2DComponent.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.playerQuery).forEach { entity in
            let body = entity.components[PhysicsBody2DComponent.self]!
            
            if Input.isKeyPressed(.space) {
                body.applyLinearImpulse([0, 1], point: .zero, wake: true)
            }
            
            for touch in Input.getTouches() where touch.phase == .began {
                body.applyLinearImpulse([0, 1], point: .zero, wake: true)
            }
        }
    }
}

struct PlayerComponent: Component { }

struct TubeComponent: Component { }

struct TubeMovementSystem: System {
    
    static let tubeQuery = EntityQuery(
        where: .has(TubeComponent.self) && .has(Transform.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.tubeQuery).forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.x -= 2 * context.deltaTime
            entity.components += transform
        }
    }
}

struct TubeDestroyerSystem: System {
    
    static let tubeQuery = EntityQuery(
        where: .has(TubeComponent.self) && .has(Transform.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.tubeQuery).forEach { entity in
            let transform = entity.components[Transform.self]!
            
            if transform.position.x < -4 {
                entity.removeFromScene()
            }
        }
    }
}

class TubeSpawnerSystem: System {
    
    var lastSpawnTime: TimeInterval = 0
    var counter: TimeInterval = 0
    
    required init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        counter += context.deltaTime
        
        if lastSpawnTime < counter {
            self.lastSpawnTime = counter + 3
            
            var transform = Transform()
            transform.scale = [0.4, 1, 1]
            transform.position.z = -4
            let position = Vector3(x: 4, y: Float.random(in: 0.4 ... 1.2), z: 0)
            transform.position = position
            
            self.spawnTube(in: context.scene, transform: transform, isUp: true)
            transform.position.y -= 1.5
            
            self.spawnTube(in: context.scene, transform: transform, isUp: false)
        }
    }
    
    private func spawnTube(in scene: Scene, transform: Transform, isUp: Bool) {
        let tube = Entity(name: "Tube")
        tube.components += TubeComponent()
        tube.components += SpriteComponent(tintColor: isUp ? .green : .blue)
        tube.components += transform
        tube.components += Collision2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1)
            ],
            mode: .trigger
        )
        
        scene.addEntity(tube)
    }
}

final class GameScene2D {
    
    var collision: Cancellable!
    var fpsCounter: Cancellable!
    
    let textureAtlas: TextureAtlas
    let characterAtlas: TextureAtlas
    
    init() {
        do {
            let tiles = try Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/tiles_packed.png"))
            let charactersTiles = try Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/characters_packed.png"))
            
            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makeScene() throws -> Scene {
        let scene = Scene()
        scene.activeCamera.projection = .orthographic
        
        // DEBUG
        scene.debugOptions = [.showPhysicsShapes]
        scene.debugPhysicsColor = .red
        
        //        var transform = Transform(scale: [0.19, 0.19, 0.19])
        //        transform.position.z = 30
        //
        //        let entityA = Entity()
        //        entityA.components += transform
        //        entityA.components += SpriteComponent(tintColor: .red)
        //
        //        transform.position.z = 0
        //        transform.position.x = 0.5
        //
        //        let entityB = Entity()
        //        entityB.components += transform
        //        entityB.components += SpriteComponent(tintColor: .green)
        //
        //        scene.addEntity(entityA)
        //        scene.addEntity(entityB)
        
        self.makeBackground(for: scene)
        self.makePlayer(for: scene)
        self.makeGround(for: scene)
        self.collisionHandler(for: scene)
        self.fpsCounter(for: scene)
        
        scene.addSystem(TubeMovementSystem.self)
        scene.addSystem(TubeSpawnerSystem.self)
        scene.addSystem(TubeDestroyerSystem.self)
        scene.addSystem(PlayerMovementSystem.self)
        
        return scene
    }
    
    private func collisionHandler(for scene: Scene) {
        self.collision = scene.subscribe(CollisionEvent.Began.self) { event in
            if event.entityA.name == "Player" && (event.entityB.name == "Tube") {
                //                event.entityA.scene?.removeEntity(event.entityA)
                print("collide with tube")
                //                self.gameOver()
            }
        }
    }
    
    private func makeBackground(for scene: Scene) {
        var transform = Transform()
        transform.scale = [10, 10, 10]
        transform.position.z = 5
        
        let untexturedEntity = Entity(name: "Background")
        untexturedEntity.components += SpriteComponent(tintColor: Color(135/255, 206/255, 235/255, 1))
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
    }
    
    private func makePlayer(for scene: Scene) {
        
        var transform = Transform()
        transform.scale = [0.2, 0.2, 0.2]
        
        let playerTexture = AnimatedTexture()
        playerTexture.framesPerSecond = 5
        playerTexture.framesCount = 2
        playerTexture[0] = self.characterAtlas[0, 0]
        playerTexture[1] = self.characterAtlas[1, 0]
        
        let playerEntity = Entity(name: "Player")
        playerEntity.components += SpriteComponent(texture: playerTexture)
        playerEntity.components += transform
        playerEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: transform.scale.x, height: transform.scale.y)
            ],
            mass: 1,
            mode: .dynamic
        )
        playerEntity.components += PlayerComponent()
        scene.addEntity(playerEntity)
    }
    
    private func makeGround(for scene: Scene) {
        var transform = Transform()
        transform.scale = [3, 0.19, 0.19]
        transform.position.y = -4.9
        
        let untexturedEntity = Entity(name: "Ground")
        untexturedEntity.components += SpriteComponent(texture: self.textureAtlas[0, 0])
        untexturedEntity.components += transform
        untexturedEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 1)
            ],
            mass: 0,
            mode: .static
        )
        
        scene.addEntity(untexturedEntity)
    }
    
    private func gameOver() {
        print("Game Over")
    }
    
    private func fpsCounter(for scene: Scene) {
        self.fpsCounter = EventManager.default.subscribe(for: EngineEvent.FramesPerSecondEvent.self, completion: { event in
            //            print("FPS", event.framesPerSecond)
        })
    }
}
