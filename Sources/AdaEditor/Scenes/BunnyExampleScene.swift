//
//  StressExampleScene.swift
//
//
//  Created by Vladislav Prusakov on 06.06.2024.
//

import AdaEngine

final class ManySpritesExampleScene: Scene, @unchecked Sendable {
    override func sceneDidMove(to view: SceneView) {
        let tilesImage = try! AssetsManager.loadSync("Assets/tiles_packed.png", from: Bundle.editor) as Image
        
        let characterAtlas = TextureAtlas(from: tilesImage, size: [18, 18])
        
        self.spawnEntityes(atlas: characterAtlas)
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 20

        world.addEntity(cameraEntity)
        world.addSystem(CamMovementSystem.self)
    }
    
    func spawnEntityes(atlas: TextureAtlas) {
        let mapSize = Vector2(100)
        
        let halfX = Int(mapSize.x / 2.0)
        let halfY = Int(mapSize.y / 2.0)
        
        var entities: Int = 0
        
        for y in -halfY..<halfY {
            for x in -halfX..<halfX {
                let position = Vector2(x: Float(x), y: Float(y))
                let translation = Vector3(position, 1)
                let rotation = Quat(axis: Vector3(x: 0, y: 0, z: 1), angle: .random(in: 0..<2))
                let scale = Vector3(.random(in: 0.3..<1))
                
                let ent = Entity {
                    Transform(rotation: rotation, scale: scale, position: translation)
                    SpriteComponent(texture: atlas[Int.random(in: 0..<20), Int.random(in: 0..<9)])
//                    NoFrustumCulling()
                }
                
                self.world.addEntity(ent)
                
                entities += 1
            }
        }
        
        print("Spawned entities", entities)
    }
    
    struct CamMovementSystem: System {
        
        static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
        
        init(world: World) { }
        
        func update(context: UpdateContext) {
            let cameraEntity: Entity = context.world.performQuery(Self.cameraQuery).first!
            
            var (camera, cameraTransform) = cameraEntity.components[Camera.self, Transform.self]
            
            let speed: Float = Input.isKeyPressed(.space) ? 13 : 7
            let speedNormalized: Float = speed * context.deltaTime
            
            if Input.isKeyPressed(.w) {
                cameraTransform.position.y += speedNormalized
            }
            
            if Input.isKeyPressed(.s) {
                cameraTransform.position.y -= speedNormalized
            }
            
            if Input.isKeyPressed(.a) {
                cameraTransform.position.x -= speedNormalized
            }
            
            if Input.isKeyPressed(.d) {
                cameraTransform.position.x += speedNormalized
            }
            
            if Input.isKeyPressed(.arrowUp) {
                camera.orthographicScale -= speedNormalized
            }
            
            if Input.isKeyPressed(.arrowDown) {
                camera.orthographicScale += speedNormalized
            }
            
            cameraEntity.components += cameraTransform
            cameraEntity.components += camera
        }
    }

}
