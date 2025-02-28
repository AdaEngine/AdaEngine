//
//  GameScene2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

class GameScene2D: Scene {

    var disposeBag: Set<AnyCancellable> = []

    var textureAtlas: TextureAtlas!
    var characterAtlas: TextureAtlas!

    
    override func sceneDidMove(to view: SceneView) {
        
        do {
            let tiles = try ResourceManager.loadSync("Assets/tiles_packed.png", from: Bundle.editor) as Image
            let charactersTiles = try ResourceManager.loadSync("Assets/characters_packed.png", from: Bundle.editor) as Image

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        self.addEntity(cameraEntity)

        // DEBUG
        self.debugOptions = [.showPhysicsShapes]
        self.makePlayer()
        self.makeGround()
        try! self.makeCanvasItem(position: [-0.3, 0.4, -1])
        self.collisionHandler()
        
        self.addSystem(PlayerMovementSystem.self)
        self.addSystem(SpawnPhysicsBodiesSystem.self)

        // Change gravitation
    }

    override func sceneDidLoad() {
        self.physicsWorld2D?.gravity = Vector2(0, -3.62)
    }

    private func collisionHandler() {
        self.subscribe(to: CollisionEvents.Began.self) { event in
            if event.entityA.name == "Player" && (event.entityB.name == "Tube") {
                //                event.entityA.scene?.removeEntity(event.entityA)
                //                print("collide with tube")
                //                self.gameOver()
            }
        }
        .store(in: &disposeBag)
    }

    private func makePlayer() {

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
                .generateBox()
            ],
            mass: 1,
            mode: .kinematic
        )
        playerEntity.components += PlayerComponent()
        self.addEntity(playerEntity)
    }

    func makeCanvasItem(position: Vector3) throws {
        let dogTexture = try ResourceManager.loadSync("Assets/dog.png", from: Bundle.editor) as Texture2D

        @CustomMaterial var material = MyMaterial(color: .red, customTexture: dogTexture)

        let mesh = Mesh2DComponent(
            mesh: Mesh.generate(from: Quad()),
            materials: [$material]
        )

        var transform = Transform()
        transform.scale = Vector3(0.4)
        transform.position.z = position.z
        transform.position.x = position.x
        transform.position.y = position.y

        let entity = Entity(name: "custom_material")
        entity.components += mesh
        entity.components += transform
        self.addEntity(entity)
    }

    private func makeGround() {
        var transform = Transform()
        transform.scale = [3, 0.19, 0.19]
        transform.position.y = -1

        let untexturedEntity = Entity(name: "Ground")
        untexturedEntity.components += SpriteComponent(texture: self.textureAtlas[0, 0])
        untexturedEntity.components += transform
        untexturedEntity.components += Collision2DComponent(
            shapes: [
                .generateBox()
            ]
        )

        self.addEntity(untexturedEntity)
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
        attributes.font = Font.system(size: 0, weight: .ultraLight)

        var text = AttributedText("Hello, Ada Engine!\n", attributes: attributes)

        attributes.font = Font.system(size: 0, weight: .regular)
        attributes.foregroundColor = .purple
        attributes.kern = -0.03

        text += AttributedText("And my dear friends!", attributes: attributes)

        attributes.foregroundColor = .brown
        attributes.font = Font.system(size: 0, weight: .heavy)

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

struct PlayerMovementSystem: System {

    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(PhysicsBody2DComponent.self))

    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    static let matQuery = EntityQuery(where: .has(Mesh2DComponent.self) && .has(Transform.self))

    init(scene: Scene) { }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func update(context: UpdateContext) {
        let cameraEntity: Entity = context.scene.performQuery(Self.cameraQuery).first!

        var (camera, cameraTransform) = cameraEntity.components[Camera.self, Transform.self]

        let speed: Float = 2 * context.deltaTime

        if Input.isKeyPressed(.w) {
            cameraTransform.position.y += speed
        }

        if Input.isKeyPressed(.s) {
            cameraTransform.position.y -= speed
        }

        if Input.isKeyPressed(.a) {
            cameraTransform.position.x -= speed
        }

        if Input.isKeyPressed(.d) {
            cameraTransform.position.x += speed
        }

        if Input.isKeyPressed(.arrowUp) {
            camera.orthographicScale -= speed
        }

        if Input.isKeyPressed(.arrowDown) {
            camera.orthographicScale += speed
        }

        cameraEntity.components += cameraTransform
        cameraEntity.components += camera

        context.scene.performQuery(Self.matQuery).forEach { entity in
            let meshComponent = entity.components[Mesh2DComponent.self]!
            if Input.isMouseButtonPressed(.left) {
                (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .mint
            } else {
                (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .pink
            }

            (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.time += context.deltaTime

            var transform = entity.components[Transform.self]!

            if Input.isMouseButtonPressed(.left) {
                let globalTransform = context.scene.worldTransformMatrix(for: cameraEntity)
                let mousePosition = Input.getMousePosition()
                if let position = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform, viewportPosition: mousePosition) {
                    //                    let values = context.scene.physicsWorld2D?.raycast(from: .zero, to: position)

                    transform.position.x = position.x
                    transform.position.y = -position.y
                }
            }

            let speed: Float = 3

            if Input.isKeyPressed(.semicolon) {
                transform.position.x += speed * context.deltaTime
            }

            if Input.isKeyPressed(.k) {
                transform.position.x -= speed * context.deltaTime
            }

            if Input.isKeyPressed(.l) {
                transform.position.y -= speed * context.deltaTime
            }

            if Input.isKeyPressed(.o) {
                transform.position.y += speed * context.deltaTime
            }

            entity.components += transform
        }

//        context.scene.performQuery(Self.playerQuery).forEach { entity in
//            let body = entity.components[PhysicsBody2DComponent.self]!
//
//            if Input.isKeyPressed(.space) {
//                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
//            }
//
//            for touch in Input.getTouches() where touch.phase == .began {
//                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
//            }
//
//            if Input.isKeyPressed(.arrowLeft) {
//                body.applyLinearImpulse([-0.05, 0], point: .zero, wake: true)
//            }
//
//            if Input.isKeyPressed(.arrowRight) {
//                body.applyLinearImpulse([0.05, 0], point: .zero, wake: true)
//            }
//        }
    }
}

@Component
struct PlayerComponent { }

struct MyMaterial: CanvasMaterial {

    @Uniform(binding: 2, propertyName: "u_Time")
    var time: Float

    @Uniform(binding: 2, propertyName: "u_Color")
    var color: Color

    @FragmentTexture(binding: 0)
    var customTexture: Texture2D

    init(color: Color, customTexture: Texture2D) {
        self.time = 0
        self.color = color
        self.customTexture = customTexture
    }

    static func fragmentShader() throws -> ShaderSource {
        try ResourceManager.loadSync("Assets/custom_material.glsl", from: .editor)
    }
}

struct SpawnPhysicsBodiesSystem: System {
    
    static let camera = EntityQuery(where: .has(Camera.self))
    let fixedTimestep: FixedTimestep = FixedTimestep(stepsPerSecond: 20)

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        let result = fixedTimestep.advance(with: context.deltaTime)
        if !result.isFixedTick {
            return
        }
        
        context.scene.performQuery(Self.camera).forEach { entity in
            if Input.isMouseButtonPressed(.left) {
                let (globalTransform, camera) = entity.components[GlobalTransform.self, Camera.self]
                let mousePosition = Input.getMousePosition()
                if let position = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform.matrix, viewportPosition: mousePosition) {
                    self.spawnPhysicsBody(at: Vector3(position.x, -position.y, 1), scene: context.scene )
                }
            }
        }
    }
    
    @MainActor
    private func spawnPhysicsBody(at position: Vector3, scene: Scene) {
        let isCircle = Input.isKeyPressed(.space)

        let entity = Entity {
            PhysicsBody2DComponent(
                shapes: [
                   isCircle ? .generateCircle(radius: 1) : .generateBox()
                ],
                mass: 1,
                mode: .dynamic
            )
            
            Transform(scale: Vector3(0.4), position: position)
            
            if isCircle {
                Circle2DComponent(color: .red)
            } else {
                SpriteComponent(tintColor: .blue)
            }
        }
        
        scene.addEntity(entity)
    }
}
