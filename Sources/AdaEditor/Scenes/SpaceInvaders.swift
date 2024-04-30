//
//  SpaceInvaders.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/6/23.
//

import AdaEngine

class SpaceInvaders {

    var disposeBag: Set<AnyCancellable> = []

    let characterAtlas: TextureAtlas

    init() {
        do {
            let charactersTiles = try ResourceManager.loadSync("Assets/characters_packed.png", from: Bundle.editor) as Image
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    @MainActor
    func makeScene() async throws -> Scene {
        let scene = Scene()
        scene.debugOptions = [.showPhysicsShapes]

        let sound = try ResourceManager.loadSync("Assets/WindlessSlopes.wav", from: Bundle.editor) as AudioResource

        let camera = OrthographicCamera()
        camera.camera.clearFlags = .solid
        camera.camera.backgroundColor = .black
//        camera.prepareAudio(sound)
//            .setLoop(true)
//            .setVolume(0.6)
//            .play()

        scene.addEntity(camera)

        try self.makePlayer(for: scene)
        try self.makeScore(for: scene)

        // Systems

        scene.addSystem(MovementSystem.self)
        scene.addSystem(FireSystem.self)
        scene.addSystem(BulletSystem.self)

        scene.addSystem(EnemySpawnerSystem.self)
        scene.addSystem(EnemyMovementSystem.self)
        scene.addSystem(EnemyLifetimeSystem.self)
        scene.addSystem(EnemyExplosionSystem.self)

        scene.addSystem(ScoreSystem.self)

        scene.subscribe(to: CollisionEvents.Began.self) { event in
            if let bullet = event.entityB.components[Bullet.self], var enemy = event.entityA.components[EnemyComponent.self] {
                enemy.health -= bullet.damage

                event.entityA.components += enemy
                event.entityB.removeFromScene()
            }
        }
        .store(in: &self.disposeBag)

        scene.subscribe(to: SceneEvents.OnReady.self) { event in
            event.scene.physicsWorld2D?.gravity = .zero
        }.store(in: &self.disposeBag)

        return scene
    }
}

extension SpaceInvaders {
    func makePlayer(for scene: Scene) throws {
        let player = Entity()

        player.components += Transform(scale: Vector3(0.2), position: [0, -0.85, 0])
        player.components += PlayerComponent()
        player.components += SpriteComponent(texture: characterAtlas[7, 1])

        scene.addEntity(player)
    }

    func makeScore(for scene: Scene) throws {
        let score = Entity(name: "Score")

        var container = TextAttributeContainer()
        container.foregroundColor = .white
        let attributedText = AttributedText("Score: 0", attributes: container)

        score.components += Text2DComponent(text: attributedText)
        score.components += GameState()
        score.components += Transform(scale: Vector3(0.1), position: [-0.2, -0.9, 0])
        score.components += NoFrustumCulling()

        scene.addEntity(score)
    }
}

struct MovementSystem: System {

    static let camera = EntityQuery(where: .has(Camera.self))
    static let player = EntityQuery(where: .has(PlayerComponent.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        let cameraEntity = context.scene.performQuery(Self.camera).first!
        let camera = cameraEntity.components[Camera.self]!
        let globalTransform = context.scene.worldTransformMatrix(for: cameraEntity)

        let mousePosition = Input.getMousePosition()

        let worldPosition = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform, viewportPosition: mousePosition) ?? .zero

        context.scene.performQuery(Self.player).forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.x = worldPosition.x
            transform.position.y = -worldPosition.y

            entity.components += transform
        }
    }
}

struct FireSystem: System {

    static let player = EntityQuery(where: .has(PlayerComponent.self))

    let fixedTime = FixedTimestep(stepsPerSecond: 12)
    let laserAudio: AudioResource

    init(scene: Scene) {
        self.laserAudio = try! ResourceManager.loadSync("Assets/laserShoot.wav", from: .editor) as AudioResource
    }

    func update(context: UpdateContext) async {
        await context.scene.performQuery(Self.player).forEach { entity in
            let transform = entity.components[Transform.self]!

            if Input.isMouseButtonPressed(.left) || Input.isKeyPressed(.space) {

                let result = fixedTime.advance(with: context.deltaTime)

                if result.isFixedTick {

                    let controller = entity.prepareAudio(self.laserAudio)

                    if controller.isPlaying {
                        controller.stop()
                    }

                    controller.volume = 0.15
                    controller.play()

                    fireBullet(context: context, shipTransform: transform)
                }
            }
        }

    }

    func fireBullet(context: UpdateContext, shipTransform: Transform) {
        let bullet = Entity()

        let bulletScale = Vector3(0.02, 0.04, 0.04)

        bullet.components += Transform(scale: bulletScale, position: shipTransform.position)
        bullet.components += SpriteComponent(tintColor: .red)
        bullet.components += Bullet(lifetime: 4)

        var collision = PhysicsBody2DComponent(
            shapes: [
                .generateBox()
            ],
            mass: 1,
            mode: .dynamic
        )

        collision.filter.categoryBitMask = .bullet

        bullet.components += collision

        context.scene.addEntity(bullet)
    }
}

@Component
struct Bullet {
    var damage: Float = 30
    let lifetime: Float
    var currentLifetime: Float = 0
}

struct BulletSystem: System {

    static let bullet = EntityQuery(where: .has(Bullet.self) && .has(PhysicsBody2DComponent.self))
    static let bulletSpeed: Float = 3

    init(scene: Scene) { }

    func update(context: UpdateContext) async {
        await context.scene.performQuery(Self.bullet).concurrent.forEach { entity in
            var (bullet, body) = entity.components[Bullet.self, PhysicsBody2DComponent.self]

            body.setLinearVelocity([0, Self.bulletSpeed])
            bullet.currentLifetime += context.deltaTime

            if bullet.lifetime > bullet.currentLifetime {
                entity.components += bullet
            } else {
                entity.removeFromScene()
            }
        }
    }
}

@Component
struct EnemyComponent {
    var health: Float
    let lifetime: Float
    var currentLifetime: Float = 0
}

struct EnemySpawnerSystem: System {

    let fixedTime = FixedTimestep(stepsPerSecond: 2)

    let textureAtlas: TextureAtlas

    init(scene: Scene) {
        do {
            let tiles = try ResourceManager.loadSync("Assets/tiles_packed.png", from: Bundle.editor) as Image

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func update(context: UpdateContext) {
        let result = fixedTime.advance(with: context.deltaTime)

        if result.isFixedTick {
            self.spawnEnemy(context: context)
        }
    }

    func spawnEnemy(context: UpdateContext) {
        let entity = Entity(name: "Enemy")

        var transform = Transform()
        transform.scale = Vector3(0.25)
        transform.position = [Float.random(in: -1.8...1.8), 1, -1]
        entity.components += transform
        entity.components += SpriteComponent(texture: textureAtlas[5, 7])

        var collision = Collision2DComponent(
            shapes: [
                .generateBox()
            ],
            mode: .trigger
        )

        collision.filter.collisionBitMask = .bullet

        entity.components += collision
        entity.components += EnemyComponent(health: 100, lifetime: 12)
        context.scene.addEntity(entity)
    }
}

struct EnemyLifetimeSystem: System {
    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))

    init(scene: Scene) { }

    func update(context: UpdateContext) {
        context.scene.performQuery(Self.enemy).forEach { entity in
            var enemy = entity.components[EnemyComponent.self]!

            enemy.currentLifetime += context.deltaTime

            if enemy.lifetime > enemy.currentLifetime {
                entity.components += enemy
            } else {
                entity.removeFromScene()
            }
        }
    }
}

struct EnemyMovementSystem: System {

    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))
    static let speed: Float = 0.1

    init(scene: Scene) { }

    func update(context: UpdateContext) async {
        await context.scene.performQuery(Self.enemy).concurrent.forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.y -= Self.speed * context.deltaTime
            entity.components += transform
        }
    }
}

extension CollisionGroup {
    static let bullet = CollisionGroup(rawValue: 1 << 2)
}

@Component
struct ExplosionComponent { }

struct EnemyExplosionSystem: System {

    let exposionAtlas: TextureAtlas
    let explosionAudio: AudioResource

    init(scene: Scene) {
        let image = try! ResourceManager.loadSync("Assets/explosion.png", from: .editor) as Image
        self.exposionAtlas = TextureAtlas(from: image, size: Size(width: 32, height: 32))

        self.explosionAudio = try! ResourceManager.loadSync("Assets/explosion-1.wav", from: .editor) as AudioResource
    }

    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))
    static let explosions = EntityQuery(where: .has(ExplosionComponent.self))
    static let scores = EntityQuery(where: .has(GameState.self))

    func update(context: UpdateContext) async {
        let scores = context.scene.performQuery(Self.scores).first

        // Make expolosions
        context.scene.performQuery(Self.enemy).forEach { entity in
            let (enemy, transform) = entity.components[EnemyComponent.self, Transform.self]

            if enemy.health <= 0 {

                scores?.components[GameState.self]?.score += 1

                let texture = AnimatedTexture()
                texture.framesPerSecond = 6
                texture.framesCount = 6
                texture.options = []
                texture[0] = self.exposionAtlas[0, 0]
                texture[1] = self.exposionAtlas[1, 0]
                texture[2] = self.exposionAtlas[2, 0]
                texture[3] = self.exposionAtlas[3, 0]
                texture[4] = self.exposionAtlas[4, 0]
                texture[5] = self.exposionAtlas[5, 0]

                let explosion = Entity()
                let controller = explosion.prepareAudio(self.explosionAudio)
                controller.volume = 0.4
                controller.play()

                explosion.components += SpriteComponent(texture: texture)
                explosion.components += transform
                explosion.components += ExplosionComponent()
                context.scene.addEntity(explosion)

                entity.removeFromScene()
            }
        }

        // Remove explosions
        context.scene.performQuery(Self.explosions).forEach { entity in
            guard let texture = entity.components[SpriteComponent.self]?.texture as? AnimatedTexture else {
                return
            }

            if texture.isPaused {
                entity.removeFromScene()
            }
        }
    }
}

@Component
struct GameState {
    var score: Int = 0
}

struct ScoreSystem: System {

    static let scores = EntityQuery(where: .has(Text2DComponent.self) && .has(GameState.self))

    var container: TextAttributeContainer

    init(scene: Scene) {
        self.container = TextAttributeContainer()
        self.container.foregroundColor = .white
    }

    func update(context: UpdateContext) {
        context.scene.performQuery(Self.scores).forEach { entity in
            var (text, score) = entity.components[Text2DComponent.self, GameState.self]

            text.text = AttributedText("Score: \(score.score)", attributes: self.container)

            entity.components += text
        }
    }
}
