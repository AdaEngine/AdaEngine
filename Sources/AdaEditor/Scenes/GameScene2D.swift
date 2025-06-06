//
//  GameScene2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

@MainActor
struct GameScene2DPlugin: Plugin {

    @LocalIsolated
    private var textureAtlas: TextureAtlas!

    @LocalIsolated
    private var characterAtlas: TextureAtlas!

    @LocalIsolated
    private var disposeBag: Set<AnyCancellable> = []

    func setup(in app: AppWorlds) {
        do {
            let tiles = try AssetsManager.loadSync(
                Image.self,
                at: "@res://tiles_packed.png"
            ).asset
            let charactersTiles = try AssetsManager.loadSync(
                Image.self,
                at: "@res://characters_packed.png"
            ).asset

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.1
        app.mainWorld.addEntity(cameraEntity)

        self.makePlayer(app.mainWorld)
//        self.makeSubsceneAndSave(app)
        self.loadSubscene(app)
//        // try! self.makeCanvasItem(position: [-0.3, 0.4, -1])
        self.collisionHandler(app)
//
        app
            .addSystem(PlayerMovementSystem.self)
            .addSystem(SpawnPhysicsBodiesSystem.self)
    }

    private func collisionHandler(_ app: AppWorlds) {
        app.mainWorld.subscribe(to: CollisionEvents.Began.self) { event in
            if event.entityA.name == "Player" && (event.entityB.name == "Tube") {
                //                event.entityA.scene?.removeEntity(event.entityA)
                //                print("collide with tube")
                //                self.gameOver()
            }
        }
        .store(in: &disposeBag)
    }

    private func makePlayer(_ world: World) {
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
        world.addEntity(playerEntity)
    }

    private func makeSubsceneAndSave(_ app: AppWorlds) {
        let scene = Scene()

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

        transform.position.y = -1.5

        let texturedEntity = Entity(name: "Ground 2")
        texturedEntity.components += SpriteComponent(tintColor: .red)
        texturedEntity.components += Transform()
            .setPosition(Vector3(0, 0.3, 0))
            .setScale(Vector3(0.49, 0.49, 0.49))
        texturedEntity.components += Collision2DComponent(
            shapes: [
                .generateBox()
            ]
        )

        scene.world.addEntity(untexturedEntity)
        scene.world.addEntity(texturedEntity)

        Task {
            try await AssetsManager.save(scene, at: "@res://", name: "Subscene.ascn")

            await MainActor.run {
                self.loadSubscene(app)
            }
        }
    }

    private func loadSubscene(_ app: AppWorlds) {
        Task { @MainActor in
            do {
                let scene = try await AssetsManager.load(
                    Scene.self,
                    at: "@res://Subscene.ascn",
                    handleChanges: true
                )
                app.mainWorld.addEntity(
                    Entity(name: "Subscene") {
                        DynamicScene(scene: scene)
                    }
                )
            } catch {
                print(error)
            }
        }
    }
}

@System(dependencies: [
    .before(CameraSystem.self)
])
struct PlayerMovementSystem {

    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(PhysicsBody2DComponent.self))

    @Query<Ref<Camera>, Ref<Transform>, GlobalTransform>
    private var cameraQuery
    static let matQuery = EntityQuery(where: .has(Mesh2DComponent.self) && .has(Transform.self))

    init(world: World) { }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    func update(context: inout UpdateContext) {
        for (camera, cameraTransform, globalTransform) in cameraQuery {
            let speed: Float = 2 * context.deltaTime

            // --- Gamepad camera movement ---
            if let gamepad = Input.getConnectedGamepads().first {
                let leftStickX = gamepad.getAxisValue(.leftStickX)
                let leftStickY = gamepad.getAxisValue(.leftStickY)
                let deadzone: Float = 0.1
                if abs(leftStickX) > deadzone {
                    cameraTransform.position.x += leftStickX * speed
                }
                if abs(leftStickY) > deadzone {
                    cameraTransform.position.y += leftStickY * speed // Invert Y for typical 2D controls
                }

                let rightStickY = gamepad.getAxisValue(.rightStickY)
                if abs(rightStickY) > deadzone {
                    camera.orthographicScale -= rightStickY * speed // Invert Y for typical 2D controls
                }
            }
            // --- End gamepad camera movement ---

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

            context.world.performQuery(Self.matQuery).forEach { entity in
                let meshComponent = entity.components[Mesh2DComponent.self]!
                if Input.isMouseButtonPressed(.left) {
                    (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .mint
                } else {
                    (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.color = .pink
                }

                (meshComponent.materials[0] as? CustomMaterial<MyMaterial>)?.time += context.deltaTime

                var transform = entity.components[Transform.self]!

                if Input.isMouseButtonPressed(.left) {
                    let mousePosition = Input.getMousePosition()
                    if let position = camera.wrappedValue.viewportToWorld2D(cameraGlobalTransform: globalTransform.matrix, viewportPosition: mousePosition) {
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
        }

//        context.world.performQuery(Self.playerQuery).forEach { entity in
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

final class PlayerComponent: ScriptableComponent, @unchecked Sendable {
    
    @RequiredComponent var body: PhysicsBody2DComponent
    
    override func onUpdate(_ deltaTime: AdaEngine.TimeInterval) {
        if Input.isKeyPressed(.space) {
            body.applyLinearImpulse([0, 1], point: .zero, wake: true)
        }
    }
    
    override func onEvent(_ events: [any InputEvent]) {
        for event in events {
            if let touch = event as? TouchEvent {
                if touch.phase == .moved {
                    body.applyLinearImpulse([0, 1], point: .zero, wake: true)
                }
            }
        }
    }
}

// @Component
// struct PlayerComponent { }

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

    static func fragmentShader() throws -> AssetHandle<ShaderSource> {
        try AssetsManager.loadSync(
            ShaderSource.self, 
            at: "Assets/custom_material.glsl", 
            from: .editor
        )
    }
}

@System
struct SpawnPhysicsBodiesSystem {

    @Query<Camera, GlobalTransform>
    private var camera
    let fixedTimestep: FixedTimestep = FixedTimestep(stepsPerSecond: 20)
    
    init(world: World) { }

    func update(context: inout UpdateContext) {
        let result = fixedTimestep.advance(with: context.deltaTime)
        if !result.isFixedTick {
            return
        }
        
        self.camera.forEach { camera, globalTransform in
            if Input.isMouseButtonPressed(.left) {
                let mousePosition = Input.getMousePosition()
                if let position = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform.matrix, viewportPosition: mousePosition) {
                    self.spawnPhysicsBody(at: Vector3(position.x, -position.y, 1), world: context.world)
                }
            }

            if let gamepad = Input.getConnectedGamepads().first, gamepad.isGamepadButtonPressed(.rightTriggerButton) {
                let centerOfScreen = Vector2(camera.viewport!.rect.width / 2, camera.viewport!.rect.height / 2)
                if let position = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform.matrix, viewportPosition: centerOfScreen) {
                    self.spawnPhysicsBody(at: Vector3(position.x, -position.y, 1), world: context.world)
                }
            }
        }
    }
    
    private func spawnPhysicsBody(at position: Vector3, world: World) {
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
        
        world.addEntity(entity)
    }
}
