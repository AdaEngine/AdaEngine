//
//  File.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

class ControlCameraComponent: ScriptComponent {
    
    var speed: Float = 4
    
    @RequiredComponent var circle: Camera
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.orthographicScale += 0.1
        }

        if Input.isKeyPressed(.arrowDown) {
            self.circle.orthographicScale -= 0.1
        }

        if Input.isKeyPressed(.w) {
            self.transform.position.y -= 0.1 * speed
        }

        if Input.isKeyPressed(.s) {
            self.transform.position.y += 0.1 * speed
        }

        if Input.isKeyPressed(.a) {
            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.d) {
            self.transform.position.x += 0.1 * speed
        }
        
    }
}

class SpawnerComponent: ScriptComponent {
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.g) {
            
            var transform = self.transform
            transform.scale = [0.2, 0.2, 0.2]
            transform.position.x += Float.random(in: -0.3...0.3)
            
            let playerEntity = Entity()
            playerEntity.components += Circle2DComponent(color: .red.opacity(0.5))
            playerEntity.components += transform
            playerEntity.components += PhysicsBody2DComponent(
                shapes: [
                    .generateCircle(radius: 0.2)
                ],
                mass: 1
            )
            playerEntity.components += PlayerComponent()
            
            self.entity?.scene?.addEntity(playerEntity)
        }
    }
}

class PlayerComponent: ScriptComponent {
    
    var speed: Float = 10
    
    @RequiredComponent var body: PhysicsBody2DComponent
    
    override func update(_ deltaTime: TimeInterval) {
        
        if Input.isKeyPressed(.space) {
            body.applyLinearImpulse([0, 1], point: .zero, wake: true)
        }
        
        if Input.isKeyPressed(.m) {
            let scene = self.entity?.scene
            if scene?.debugOptions.contains(.showPhysicsShapes) == true {
                scene?.debugOptions.remove(.showPhysicsShapes)
            } else {
                scene?.debugOptions.insert(.showPhysicsShapes)
            }
        }
//
//        if Input.isKeyPressed(.arrowUp) {
//            self.transform.position.y += 0.1 * speed
//        }
//
//        if Input.isKeyPressed(.arrowDown) {
//            self.transform.position.y -= 0.1 * speed
//        }

        if Input.isKeyPressed(.arrowLeft) {
            self.body.applyForce(force: [-speed, 0], point: .zero, wake: true)
//            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.arrowRight) {
//            self.transform.position.x += 0.1 * speed
            self.body.applyForce(force: [speed, 0], point: .zero, wake: true)
        }
        
    }
    
}


class GameScene {
    
    var collision: Cancellable!
    
    func makeScene() async throws -> Scene {
        let scene = Scene()
        
        // DEBUG
        
//        scene.debugOptions = [.showPhysicsShapes]
        
        let tiles = try await Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/tiles_packed.png"))
        
        let charactersTiles = try await Image(contentsOf: Bundle.module.resourceURL!.appendingPathComponent("Assets/characters_packed.png"))
        
        let charAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        
        let playerTexture = AnimatedTexture()
        playerTexture.framesPerSecond = 5
        playerTexture.framesCount = 2
        playerTexture[0] = charAtlas[0, 0]
        playerTexture[1] = charAtlas[1, 0]
        
        let texture = TextureAtlas(from: tiles, size: [18, 18])
        
        let heartAnimated = AnimatedTexture()
        heartAnimated.framesPerSecond = 5
        heartAnimated.framesCount = 4
        heartAnimated[0] = texture[4, 2]
        heartAnimated[1] = texture[5, 2]
        heartAnimated[2] = texture[6, 2]
        heartAnimated[3] = texture[5, 2]
        
        var transform = Transform()
        transform.scale = [4, 4, 4]
        
        let untexturedEntity = Entity(name: "Background")
        untexturedEntity.components += SpriteComponent(tintColor: Color(135/255, 206/255, 235/255, 1))
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
        
        transform.position = [-0.45, 9, 0]
        transform.scale = [0.1, 0.1, 0.1]
        
        let spawner = Entity(name: "Spawner")
        spawner.components += transform
        spawner.components += SpawnerComponent()
        spawner.components += SpriteComponent(tintColor: .green)
        scene.addEntity(spawner)
        
//        transform.position = [-8, 6, 0]
//        transform.scale = [0.15, 0.15, 0.15]
        
//        let heartEntity = Entity()
//        heartEntity.components += SpriteComponent(texture: heartAnimated)
//        heartEntity.components += transform
//        scene.addEntity(heartEntity)
        
        transform.position = [-3, -2, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        let plainEntity2 = Entity(name: "floor1")
        plainEntity2.components += SpriteComponent(texture: texture[0, 0])
        plainEntity2.components += transform
        plainEntity2.components += Collision2DComponent(
            shapes: [
                .generateBox(width: 0.3, height: 0.6)
            ]
        )
        scene.addEntity(plainEntity2)
        
        transform.position = [-3, -2, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        var prevEnt: Entity = plainEntity2
        
        for i in 0...8 {
            
            transform.position.x += 0.6
            
            let joint1 = Entity(name: "joint \(i)")
            joint1.components += Circle2DComponent(color: .orange.opacity(0.5), thickness: 0.2)
            joint1.components += transform
            joint1.components += PhysicsBody2DComponent(
                shapes: [
                    .generateCircle(radius: 0.3)
                ],
                massProperties: .init(),
                material: .generate(friction: 0.2, restitution: 0, density: 20)
            )
            
            joint1.components += PhysicsJoint2DComponent(
                joint: .revolute(entityA: prevEnt)
            )
            
            prevEnt = joint1
            
            scene.addEntity(joint1)
            
        }
        
        transform.position.x += 0.3
        
        transform.position = [3, -2, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        let plainEntity1 = Entity(name: "floor2")
        plainEntity1.components += SpriteComponent(texture: texture[0, 0])
        plainEntity1.components += transform
        plainEntity1.components += Collision2DComponent(
            shapes: [
                .generateBox(width: 0.3, height: 0.6)
            ]
        )
        plainEntity1.components += PhysicsJoint2DComponent(
            joint: .revolute(entityA: prevEnt)
        )
        
        scene.addEntity(plainEntity1)
        

        
        
        
        
        
        
        

        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        userEntity.components += camera
        userEntity.components += ControlCameraComponent()
        scene.addEntity(userEntity)
        
        transform.position = [0, -10, 0]
        transform.scale = [10, 0.3, 0.3]
        
        let destroyer = Entity(name: "Destroy")
        destroyer.components += SpriteComponent(tintColor: .blue)
        destroyer.components += transform
        destroyer.components += Collision2DComponent(shapes: [
            .generateBox(width: 10, height: 0.3)
        ], mode: .trigger)
        scene.addEntity(destroyer)

//        collision = scene.subscribe(CollisionEvent.Began.self, completion: { event in
//            
//            if event.entityA.name == "Destroy" {
//                event.entityB.scene?.removeEntity(event.entityB)
//            }
//            
//        })
        
        return scene
    }
    
}
