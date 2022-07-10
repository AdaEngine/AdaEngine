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

class ControlCircleComponent: ScriptComponent {
    
    var speed: Float = 2
    
    @RequiredComponent var circle: Circle2DComponent
    
    override func update(_ deltaTime: TimeInterval) {
        if Input.isKeyPressed(.arrowUp) {
            self.circle.thickness += 0.1
        }

        if Input.isKeyPressed(.arrowDown) {
            self.circle.thickness -= 0.1
        }

        if Input.isKeyPressed(.w) {
            self.transform.position.y += 0.1 * speed
        }

        if Input.isKeyPressed(.s) {
            self.transform.position.y -= 0.1 * speed
        }

        if Input.isKeyPressed(.a) {
            self.transform.position.x -= 0.1 * speed
        }

        if Input.isKeyPressed(.d) {
            self.transform.position.x += 0.1 * speed
        }
        
    }
    
}


class GameScene {
    func makeScene() async throws -> Scene {
        let scene = Scene()
        
        // DEBUG
        
        scene.debugOptions = [.showPhysicsShapes, .showFPS]
        
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
        
        let untexturedEntity = Entity()
        untexturedEntity.components += SpriteComponent(tintColor: Color(135/255, 206/255, 235/255, 1))
        untexturedEntity.components += transform
        scene.addEntity(untexturedEntity)
        
        transform.position = [-0.45, 0.65, 0]
        transform.scale = [0.35, 0.35, 0.35]
        
        let playerEntity = Entity()
        playerEntity.components += SpriteComponent(texture: playerTexture)
        playerEntity.components += transform
        playerEntity.components += Collision2DComponent(
            shapes: [.generateBox(width: 0.3, height: 0.3)]
        )
        
        scene.addEntity(playerEntity)
        
        transform.position = [-8, 6, 0]
        transform.scale = [0.15, 0.15, 0.15]
        
        let heartEntity = Entity()
        heartEntity.components += SpriteComponent(texture: heartAnimated)
        heartEntity.components += transform
        scene.addEntity(heartEntity)
        
        transform.position = [-0.3, -0.3, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        let plainEntity = Entity()
        plainEntity.components += SpriteComponent(texture: texture[2, 0])
        plainEntity.components += transform
        scene.addEntity(plainEntity)
        
        transform.position = [-1.3, -0.3, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        let plainEntity1 = Entity()
        plainEntity1.components += SpriteComponent(texture: texture[1, 0])
        plainEntity1.components += transform
        scene.addEntity(plainEntity1)
        
        transform.position = [0.6, -0.3, 0]
        transform.scale = [0.3, 0.3, 0.3]
        
        let plainEntity2 = Entity()
        plainEntity2.components += SpriteComponent(texture: texture[3, 0])
        plainEntity2.components += transform
        scene.addEntity(plainEntity2)
        
//        for i in 0..<10 {
//            let viewEntity = Entity(name: "Circle \(i)")
//
//            let alpha: Float = Float.random(in: 0.3...1)
//
//            let color = Color(
//                Float.random(in: 0..<255) / 255,
//                Float.random(in: 0..<255) / 255,
//                Float.random(in: 0..<255) / 255,
//                alpha
//            )
            
//            viewEntity.components += Circle2DComponent(
//                color: Color(
//                    Float.random(in: 0..<255) / 255,
//                    Float.random(in: 0..<255) / 255,
//                    Float.random(in: 0..<255) / 255,
//                    alpha
//                ),
//                thickness: 1
//            )
            
//            viewEntity.components += SpriteComponent(
//                texture: nil
//            )
//
//            scene.addEntity(viewEntity)
//        }
        
//        let viewEntity = Entity(name: "Circle")
//        viewEntity.components += Circle2DComponent(color: .blue, thickness: 1)
//        scene.addEntity(viewEntity)
//
//        let viewEntity1 = Entity(name: "Circle 1")
//        viewEntity1.components += Circle2DComponent(color: .yellow, thickness: 1)
//
//        var transform = Transform()
//        transform.position = [4, 4, 4]
//        transform.scale = [0.2, 0.2, 0.2]
//        viewEntity1.components += transform
//        viewEntity1.components += ControlCircleComponent()
//        scene.addEntity(viewEntity1)
        
        let userEntity = Entity(name: "camera")
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        userEntity.components += camera
        userEntity.components += ControlCameraComponent()
        scene.addEntity(userEntity)
        
        return scene
    }
    
}
