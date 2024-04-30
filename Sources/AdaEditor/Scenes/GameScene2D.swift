//
//  GameScene2D.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/7/22.
//

import AdaEngine

struct PlayerMovementSystem: System {

    static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(PhysicsBody2DComponent.self))

    static let cameraQuery = EntityQuery(where: .has(Camera.self) && .has(Transform.self))
    static let matQuery = EntityQuery(where: .has(Mesh2DComponent.self) && .has(Transform.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) async {
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

        await context.scene.performQuery(Self.matQuery).forEach { entity in
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
                    print("Position", position)
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

        await context.scene.performQuery(Self.playerQuery).forEach { entity in
            let body = entity.components[PhysicsBody2DComponent.self]!

            if Input.isKeyPressed(.space) {
                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
            }

            for touch in Input.getTouches() where touch.phase == .began {
                body.applyLinearImpulse([0, 0.15], point: .zero, wake: true)
            }

            if Input.isKeyPressed(.arrowLeft) {
                body.applyLinearImpulse([-0.05, 0], point: .zero, wake: true)
            }

            if Input.isKeyPressed(.arrowRight) {
                body.applyLinearImpulse([0.05, 0], point: .zero, wake: true)
            }
        }
    }
}

@Component
struct PlayerComponent { }

@Component
struct TubeComponent { }

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
                .generateBox()
            ]
        )

        scene.addEntity(tube)
    }
}

@MainActor
final class GameScene2D {

    var disposeBag: Set<AnyCancellable> = []

    let textureAtlas: TextureAtlas
    let characterAtlas: TextureAtlas

    init() {
        do {
            let tiles = try ResourceManager.loadSync("Assets/tiles_packed.png", from: Bundle.editor) as Image
            let charactersTiles = try ResourceManager.loadSync("Assets/characters_packed.png", from: Bundle.editor) as Image

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func makeScene() async throws -> Scene {
        //        let scenePath = "@res:Scene/MyFirstScene"

        let scene = Scene()
        //        let scene = try ResourceManager.load(scenePath) as Scene

        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(135/255, 206/255, 235/255, 1)
        cameraEntity.camera.clearFlags = .solid
        cameraEntity.camera.orthographicScale = 1.5

        scene.addEntity(cameraEntity)

        // DEBUG
        scene.debugOptions = [.showPhysicsShapes]
        //        scene.debugOptions = [.showBoundingBoxes]
        scene.debugPhysicsColor = .red
        self.makePlayer(for: scene)
        self.makeGround(for: scene)
        try await self.makeCanvasItem(for: scene, position: [-0.3, 0.4, -1])
        self.collisionHandler(for: scene)
        //        self.fpsCounter(for: scene)
        await self.addText(to: scene)

        scene.addSystem(TubeMovementSystem.self)
        scene.addSystem(TubeSpawnerSystem.self)
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
        scene.physicsWorld2D?.gravity = Vector2(0, -3.62)
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
                .generateBox()
            ],
            mass: 1,
            mode: .dynamic
        )
        playerEntity.components += PlayerComponent()
        scene.addEntity(playerEntity)
    }

    func makeCanvasItem(for scene: Scene, position: Vector3) async throws {
        let dogTexture = try await ResourceManager.load("Assets/dog.png", from: Bundle.editor) as Texture2D

        let material = MyMaterial(
            color: .red,
            customTexture: dogTexture
        )

        let handle = CustomMaterial(material)

        let mesh = Mesh2DComponent(
            mesh: Mesh.generate(from: Quad()),
            materials: [handle]
        )

        var transform = Transform()
        transform.scale = Vector3(0.4)
        transform.position.z = position.z
        transform.position.x = position.x
        transform.position.y = position.y

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
        untexturedEntity.components += Collision2DComponent(
            shapes: [
                .generateBox()
            ]
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
    func addText(to scene: Scene) async {
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
