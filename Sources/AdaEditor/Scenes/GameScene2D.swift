//
//  GameScene2D.swift
//  
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

struct PlayerMovementSystem: System {
    
    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(PhysicsBody2DComponent.self))
    
    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    static let matQuery = EntityQuery(where: .has(Mesh2dComponent.self) && .has(Transform.self))
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.matQuery).forEach { entity in
            let meshComponent = entity.components[Mesh2dComponent.self]!
            if Input.isMouseButtonPressed(.left) {
                (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .mint
            } else {
                (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .pink
            }
            
            var transform = entity.components[Transform.self]!
            
            if Input.isKeyPressed(.arrowLeft) {
                transform.position.x -= 4 * context.deltaTime
            }
            
            if Input.isKeyPressed(.arrowRight) {
                transform.position.x += 4 * context.deltaTime
            }
            
            entity.components += transform
        }
        
        context.scene.performQuery(Self.playerQuery).forEach { entity in
            let body = entity.components[PhysicsBody2DComponent.self]!
            
            if Input.isKeyPressed(.space) {
                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
            }
            
            for touch in Input.getTouches() where touch.phase == .began {
                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
            }
            
//            if Input.isKeyPressed(.arrowLeft) {
//                body.applyLinearImpulse([-0.05, 0], point: .zero, wake: true)
//            }
//
//            if Input.isKeyPressed(.arrowRight) {
//                body.applyLinearImpulse([0.05, 0], point: .zero, wake: true)
//            }
        }
        
        context.scene.performQuery(Self.cameraQuery).forEach { entity in
            var (camera, transform) = entity.components[Camera.self, Transform.self]
            
            let speed: Float = 2 * context.deltaTime
            
            if Input.isKeyPressed(.w) {
                transform.position.y += speed
            }
            
            if Input.isKeyPressed(.s) {
                transform.position.y -= speed
            }
            
            if Input.isKeyPressed(.a) {
                transform.position.x -= speed
            }
            
            if Input.isKeyPressed(.d) {
                transform.position.x += speed
            }
            
            if Input.isKeyPressed(.arrowUp) {
                camera.orthographicScale -= speed
            }
            
            if Input.isKeyPressed(.arrowDown) {
                camera.orthographicScale += speed
            }
            
            entity.components += transform
            entity.components += camera
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
            transform.position.x -= 1 * context.deltaTime
            entity.components[Transform.self] = transform
        }
    }
}

struct TubeDestroyerSystem: System {
    
    static let tubeQuery = EntityQuery(
        where: .has(TubeComponent.self) && .has(Transform.self)
    )
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let entities = context.scene.performQuery(Self.tubeQuery)
        
        entities.forEach { entity in
            let transform = entity.components[Transform.self]!
            
            if transform.position.x < -4 {
                entity.removeFromScene()
            }
        }
    }
}

class TubeSpawnerSystem: System {
    
    let timer = FixedTimestep(step: 1.2)
    
    required init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        let timerResult = timer.advance(with: context.deltaTime)
        
        if timerResult.isFixedTick {
            var transform = Transform()
            transform.scale = [0.4, 1, 1]
            
            let position = Vector3(x: 4, y: Float.random(in: 0.4 ... 1.2), z: -1)
            transform.position = position
            
            self.spawnTube(in: context.scene, transform: transform, isUp: true)
            transform.position.y -= 1.5
            
            self.spawnTube(in: context.scene, transform: transform, isUp: false)
        }
    }
    
    private func spawnTube(in scene: Scene, transform: Transform, isUp: Bool) {
        let tube = Entity(name: "Tube")
        tube.components += TubeComponent()
        tube.components += SpriteComponent(tintColor: isUp ? Color.green : Color.blue)
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
    
    var disposeBag: Set<AnyCancellable> = []
    
    let textureAtlas: TextureAtlas
    let characterAtlas: TextureAtlas
    
    init() {
        do {
            let tiles = try ResourceManager.load("Assets/tiles_packed.png", from: Bundle.module) as Image
            let charactersTiles = try ResourceManager.load("Assets/characters_packed.png", from: Bundle.module) as Image
            
            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makeScene() throws -> Scene {
        
//        let scenePath = "@res:Scene/MyFirstScene"
        
        TubeMovementSystem.registerSystem()
        TubeSpawnerSystem.registerSystem()
        TubeDestroyerSystem.registerSystem()
        PlayerMovementSystem.registerSystem()
        
        let scene = Scene()
//        let scene = try ResourceManager.load(scenePath) as Scene
        
        let cameraEntity = CameraEntity()
        cameraEntity.camera.projection = .orthographic
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5
        
        scene.addEntity(cameraEntity)
        
        // DEBUG
//        scene.debugOptions = [.showPhysicsShapes]
//        scene.debugOptions = [.showBoundingBoxes]
        scene.debugPhysicsColor = .red
        self.makePlayer(for: scene)
        self.makeGround(for: scene)
        try self.makeCanvasItem(for: scene)
        self.collisionHandler(for: scene)
//        self.fpsCounter(for: scene)
        self.addText(to: scene)
        
        scene.addSystem(TubeMovementSystem.self)
//        scene.addSystem(TubeSpawnerSystem.self)
        scene.addSystem(TubeDestroyerSystem.self)
        scene.addSystem(PlayerMovementSystem.self)
        
//        try ResourceManager.save(scene, at: scenePath)
        
        // Change gravitation
        scene.subscribe(to: SceneEvents.OnReady.self, on: scene) { [weak self] event in
            self?.sceneDidReady(event.scene)
        }
        .store(in: &disposeBag)

        return scene
    }
    
    private func sceneDidReady(_ scene: Scene) {
        let physicsQuery = EntityQuery(where: .has(Physics2DWorldComponent.self))
        scene.performQuery(physicsQuery).forEach { entity in
            entity.components[Physics2DWorldComponent.self]?.world.gravity = Vector2(0, -3.62)
        }
    }
    
    private func collisionHandler(for scene: Scene) {
        scene.subscribe(to: CollisionEvents.Began.self) { event in
            if event.entityA.name == "Player" && (event.entityB.name == "Tube") {
                //                event.entityA.scene?.removeEntity(event.entityA)
//                print("collide with tube")
                //                self.gameOver()
            }
        }
        .store(in: &disposeBag)
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
    
    func makeCanvasItem(for scene: Scene) throws {
        let material = MyMaterial(color: .red)
        
        let handle = CustomMaterial(material)
        
        let mesh = Mesh2dComponent(
            mesh: Mesh.generate(from: Quad()),
            materials: [handle]
        )
        
        var transform = Transform()
        transform.scale = Vector3(1.4)
        transform.position.z = 1
        
        let entity = Entity(name: "custom_material")
        entity.components += mesh
        entity.components += NoFrustumCulling()
        entity.components += transform
        scene.addEntity(entity)
    }
    
    private func makeGround(for scene: Scene) {
        var transform = Transform()
        transform.scale = [3, 0.19, 0.19]
        transform.position.y = -1
        
        let untexturedEntity = Entity(name: "Ground")
        untexturedEntity.components += SpriteComponent(texture: self.textureAtlas[0, 0])
        untexturedEntity.components += transform
        untexturedEntity.components += PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 1, height: 1).offsetBy(x: 0, y: 0.065)
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
        EventManager.default.subscribe(to: EngineEvents.FramesPerSecondEvent.self, completion: { _ in
//            print("FPS", event.framesPerSecond)
        })
        .store(in: &disposeBag)
    }
}

extension GameScene2D {
    func addText(to scene: Scene) {
        let entity = Entity()
        var transform = Transform()
        transform.scale = Vector3(0.3)
        transform.position.x = -1
        transform.position.z = -1
        transform.position.y = 0
        entity.components += transform
        entity.components += NoFrustumCulling()
        
        var attributes = TextAttributeContainer()
        attributes.foregroundColor = .red
        attributes.outlineColor = .black
        attributes.font = Font.system(weight: .italic)
        
        var text = AttributedText("Hello, Ada Engine!\n", attributes: attributes)
        
        attributes.font = Font.system(weight: .regular)
        attributes.foregroundColor = .purple
        attributes.kern = -0.03
        
        text += AttributedText("And my dear friends!", attributes: attributes)
        
        attributes.foregroundColor = .brown
        attributes.font = .system(weight: .heavy)
        
        text.setAttributes(
            attributes,
            at: text.startIndex..<text.index(text.startIndex, offsetBy: 5)
        )
        
        entity.components += Text2DComponent(
            text: text,
            bounds: Rect(x: 0, y: 0, width: .infinity, height: .infinity),
            lineBreakMode: .byWordWrapping
        )
        
        scene.addEntity(entity)
    }
}

struct MyMaterial: CanvasMaterial {
    @Uniform(binding: 2, propertyName: "u_Color")
    var color: Color = .red
    
    static func fragmentShader() throws -> ShaderSource {
        try ResourceManager.load("Assets/custom_material.glsl", from: .module)
    }
}
