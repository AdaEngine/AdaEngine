//
//  SpaceInvaders.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/6/23.
//

import AdaEngine

/// FIXME: This scene has a bug with animated texture. They doesn't dispawned correctly..

@main
struct SpaceInvadersApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                SpaceInvaders(),
            )
            .windowMode(.windowed)
    }
}

@MainActor
struct SpaceInvaders: Plugin {
    @Local var disposeBag: Set<AnyCancellable> = []
    @Local var characterAtlas: TextureAtlas!

    func setup(in app: borrowing AppWorlds) {
        let sound = try! AssetsManager.loadSync(
            AudioResource.self,
            at: "Resources/WindlessSlopes.wav",
            from: Bundle.module
        ).asset

        let charactersTiles = try! AssetsManager.loadSync(
            Image.self,
            at: "Resources/characters_packed.png",
            from: Bundle.module
        )

        self.characterAtlas = TextureAtlas(
            from: charactersTiles.asset!, size: [20, 23], margin: [4, 1])

        var camera = Camera()
        camera.clearFlags = .solid
        camera.backgroundColor = .black

        try! self.makePlayer(in: app)
        try! self.makeScore(in: app)

        let entity = app.main.spawn(bundle: OrthographicCameraBundle(camera: camera))
        entity.prepareAudio(sound!)
            .setLoop(true)
            .setVolume(0.6)
            .play()

        app.main.subscribe(to: CollisionEvents.Began.self) { event in
            if let bullet = event.entityB.components[Bullet.self],
                var enemy = event.entityA.components[EnemyComponent.self]
            {
                enemy.health -= bullet.damage

                event.entityA.components += enemy
                event.entityB.removeFromWorld()
            }
        }
        .store(in: &self.disposeBag)

        app.main.subscribe(to: SceneEvents.OnReady.self) { event in
            Task { @MainActor in
                event.scene.world.physicsWorld2D?.gravity = .zero
            }
        }.store(in: &self.disposeBag)

        app.main.addSystem(MovementSystem.self)
        app.main.addSystem(FireSystem.self)
        app.main.addSystem(BulletSystem.self)
        app.main.addSystem(EnemySpawnerSystem.self)
        app.main.addSystem(EnemyMovementSystem.self)
        app.main.addSystem(EnemyLifetimeSystem.self)
        app.main.addSystem(EnemyExplosionSystem.self)

        app.main.addSystem(ScoreSystem.self)
    }

    private func makePlayer(in app: borrowing AppWorlds) throws {
        app.main.spawn {
            Transform(scale: Vector3(0.2), position: [0, -0.85, 0])
            PlayerComponent()
            SpriteComponent(texture: characterAtlas[7, 1])
        }
    }

    private func makeScore(in app: borrowing AppWorlds) throws {
        var container = TextAttributeContainer()
        container.foregroundColor = .white
        let attributedText = AttributedText("Score: 0", attributes: container)

        app.main.spawn("Score") {
            TextComponent(text: attributedText)
            Transform(scale: Vector3(0.1), position: [-0.2, -0.9, 0])
            NoFrustumCulling()
        }

        app.insertResource(GameState())
    }
}

@Component
struct PlayerComponent {}

@Component
struct Bullet {
    var damage: Float = 30
    let lifetime: Float
    var currentLifetime: Float = 0
}

@Component
struct EnemyComponent {
    var health: Float
    let lifetime: Float
    var currentLifetime: Float = 0
}

struct GameState: Resource {
    var score: Int = 0
}

extension CollisionGroup {
   static let bullet = CollisionGroup(rawValue: 1 << 2)
}

@Component
struct ExplosionComponent { }

@System
func Movement(
    _ cameras: Query<GlobalTransform, Camera>,
    _ players: FilterQuery<Ref<Transform>, With<PlayerComponent>>,
    _ input: Res<Input>
) {
    guard let (globalTransform, camera) = cameras.first else {
        return
    }
    let mousePosition = input.wrappedValue.getMousePosition()
    let worldPosition =
        camera.viewportToWorld2D(
            cameraGlobalTransform: globalTransform.matrix,
            viewportPosition: mousePosition
        ) ?? .zero

    players.forEach { transform in
        transform.position.x = worldPosition.x
        transform.position.y = -worldPosition.y
    }
}

@PlainSystem
struct FireSystem {

    @FilterQuery<Entity, Ref<Transform>, With<PlayerComponent>>
    private var players

    @Local
    private var fixedTime = FixedTimestep(stepsPerSecond: 12)

    let laserAudio: AudioResource

    @Res<DeltaTime>
    private var deltaTime

    @Res<Input>
    private var input

    @Commands
    private var commands

    init(world: World) {
        self.laserAudio = try! AssetsManager.loadSync(
            AudioResource.self,
            at: "Resources/laserShoot.wav",
            from: .module
        ).asset
    }

    func update(context: UpdateContext) async {
        await self.players.forEach { entity, transform in
            if input.isMouseButtonPressed(.left) || input.isKeyPressed(.space) {

                let result = fixedTime.advance(with: deltaTime.deltaTime)

                if result.isFixedTick {
                    let controller = await entity.prepareAudio(self.laserAudio)

                    if controller.isPlaying {
                        controller.stop()
                    }

                    controller.volume = 0.15
                    controller.play()

                    fireBullet(shipTransform: transform.wrappedValue)
                }
            }
        }
    }

    func fireBullet(shipTransform: Transform) {
        let bulletScale = Vector3(0.02, 0.04, 0.04)
        
        var collision = PhysicsBody2DComponent(
            shapes: [
                .generateBox()
            ],
            mass: 1,
            mode: .dynamic
        )
        collision.filter.categoryBitMask = .bullet

        commands.spawn("Bullet") { [collision] in
            Transform(scale: bulletScale, position: shipTransform.position)
            SpriteComponent(tintColor: .red)
            Bullet(lifetime: 4)
            collision
        }
    }
}

@PlainSystem
struct BulletSystem {

    @Query<Entity, Ref<Bullet>, Ref<PhysicsBody2DComponent>>
    private var bullets

    let bulletSpeed: Float = 3

    @Res<DeltaTime>
    private var deltaTime

    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        bullets.forEach { entity, bullet, body in
            body.linearVelocity = [0, bulletSpeed]
            bullet.currentLifetime += deltaTime.deltaTime

            if bullet.wrappedValue.lifetime < bullet.currentLifetime {
                commands.entity(entity.id)
                    .removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct EnemySpawnerSystem {

    @Local
    private var fixedTime = FixedTimestep(stepsPerSecond: 2)

    let textureAtlas: TextureAtlas

    @Res<DeltaTime>
    private var deltaTime

    @Commands
    private var commands

    init(world: World) {
        do {
            let tiles = try AssetsManager.loadSync(
                Image.self,
                at: "Resources/tiles_packed.png",
                from: Bundle.module
            ).asset!

            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    func update(context: UpdateContext) async {
        let result = fixedTime.advance(with: deltaTime.deltaTime)

        if result.isFixedTick {
            self.spawnEnemy()
        }
    }

    func spawnEnemy() {
        var collision = Collision2DComponent(
            shapes: [
                .generateBox()
            ],
            mode: .trigger
        )
        collision.filter.collisionBitMask = .bullet
        commands.spawn("Enemy") { [collision] in
            Transform(
                scale: Vector3(0.25),
                position: [Float.random(in: -1.8...1.8), 1, -1]
            )
            SpriteComponent(texture: textureAtlas[5, 7])
            EnemyComponent(health: 100, lifetime: 12)
            collision
        }
    }
}

@PlainSystem
struct EnemyLifetimeSystem {
    @Query<Entity, Ref<EnemyComponent>>
    private var enemies

    @Res<DeltaTime>
    private var deltaTime

    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) async {
        enemies.forEach { entity, enemy in
            enemy.currentLifetime += deltaTime.deltaTime

            if enemy.wrappedValue.lifetime < enemy.currentLifetime {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct EnemyMovementSystem {

    @FilterQuery<Ref<Transform>, With<EnemyComponent>>
    private var enemies
    let speed: Float = 0.1

    @Res<DeltaTime>
    private var deltaTime

    init(world: World) { }

    func update(context: UpdateContext) {
        enemies.forEach { transform in
            transform.position.y -= speed * deltaTime.deltaTime
        }
    }
}

@PlainSystem
struct EnemyExplosionSystem {

    let exposionAtlas: TextureAtlas
    let explosionAudio: AudioResource

    init(world: World) {
        do {
            let image = try AssetsManager.loadSync(
                Image.self,
                at: "Resources/explosion.png",
                from: .module
            ).asset!
            self.exposionAtlas = TextureAtlas(from: image, size: SizeInt(width: 32, height: 32))

            self.explosionAudio = try AssetsManager.loadSync(
                AudioResource.self,
                at: "Resources/explosion-1.wav",
                from: .module
            ).asset!
        } catch {
            fatalError("Can't load assets \(error)")
        }
    }

    @Query<Entity, EnemyComponent, Transform>
    private var enemies

    @FilterQuery<Entity, SpriteComponent, With<ExplosionComponent>>
    private var explosions

    @ResMut<GameState>
    private var score

    @Commands
    private var commands

    func update(context: UpdateContext) async {
        // Make expolosions
        await enemies.forEach { entity, enemy, transform in
            if enemy.health <= 0 {
                score.score += 1

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

                let explosion = context.world.spawn {
                    SpriteComponent(texture: texture)
                    transform
                    ExplosionComponent()
                }
                let controller = await explosion.prepareAudio(self.explosionAudio)
                controller.volume = 0.4
                controller.play()
                commands.entity(entity.id).removeFromWorld()
            }
        }

        // Remove explosions
        explosions.forEach { entity, sprite in
            guard let texture = sprite.texture?.asset as? AnimatedTexture else {
                return
            }

            if texture.isPaused {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct ScoreSystem {
    @Query<Ref<TextComponent>>
    private var scores

    @Res<GameState>
    private var score

    @Local<TextAttributeContainer>
    private var container = TextAttributeContainer()

    init(world: World) {
        container = TextAttributeContainer()
        container.foregroundColor = .white
    }

    func update(context: UpdateContext) async {
        scores.forEach { text in
            text.text = AttributedText("Score: \(score.score)", attributes: container)
        }
    }
}
