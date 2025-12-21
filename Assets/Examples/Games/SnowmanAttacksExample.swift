//
//  SpaceInvaders.swift
//  AdaEngine
//
//  Created by v.prusakov on 4/6/23.
//

import AdaEngine

@main
struct SnowmanAttacksApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(
                DefaultPlugins(),
                SnowmanAttacks()
            )
            .windowMode(.windowed)
    }
}

@MainActor
struct SnowmanAttacks: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app
            .addSystem(SetupSceneSystem.self, on: .startup)
            .addSystem(MovementSystem.self)
            .addSystem(FireSystem.self)
            .addSystem(BulletSystem.self)
            .addSystem(EnemySpawnerSystem.self)
            .addSystem(EnemyMovementSystem.self)
            .addSystem(EnemyLifetimeSystem.self)
            .addSystem(EnemyExplosionSystem.self)
            .addSystem(OnCollideSystem.self, on: .postUpdate)
            .addSystem(ScoreSystem.self)
            .insertResource(PhysicsDebugOptions([.showPhysicsShapes, .showBoundingBoxes]))
    }
}

@PlainSystem
struct SetupSceneSystem {

    @Local var characterAtlas: TextureAtlas!

    @Res<Physics2DWorldHolder>
    private var physicsWorld

    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) async {
        let sound = try! await AssetsManager.load(
            AudioResource.self,
            at: "Resources/WindlessSlopes.wav",
            from: Bundle.module
        ).asset

        let charactersTiles = try! await AssetsManager.load(
            Image.self,
            at: "Resources/characters_packed.png",
            from: Bundle.module
        )

        self.characterAtlas = TextureAtlas(
            from: charactersTiles.asset!,
            size: [20, 23],
            margin: [4, 1]
        )

        var camera = Camera()
        camera.backgroundColor = .black

        try! self.makePlayer()
        try! self.makeScore()

        let entity = context.world.spawn(bundle: Camera2D(camera: camera))
        await entity.prepareAudio(sound!)
            .setLoop(true)
            .setVolume(0.6)
            .play()

        physicsWorld.world.gravity = .zero

        do {
            let image = try await AssetsManager.load(
                Image.self,
                at: "Resources/explosion.png",
                from: .module
            ).asset!
            let explosionAtlas = TextureAtlas(from: image, size: SizeInt(width: 32, height: 32))

            let explosionAudio = try await AssetsManager.load(
                AudioResource.self,
                at: "Resources/explosion-1.wav",
                from: .module
            ).asset!

            let laserAudio = try await AssetsManager.load(
                AudioResource.self,
                at: "Resources/laserShoot.wav",
                from: .module
            ).asset!

            commands.insertResource(ExplosionResources(texture: explosionAtlas, audio: explosionAudio))
            commands.insertResource(LaserResource(audio: laserAudio))
        } catch {
            fatalError("Can't load assets \(error)")
        }
    }

    private func makePlayer() throws {
        commands.spawn {
            Transform(position: [0, 0, 0])
            PlayerComponent()
            Sprite(
                texture: characterAtlas[7, 1],
                size: .spriteSize
            )
        }
    }

    private func makeScore() throws {
        var container = TextAttributeContainer()
        container.foregroundColor = .white
        container.font = .system(size:  36)
        let attributedText = AttributedText("Score: 0", attributes: container)

        commands.spawn(
            "Score",
            bundle: Text2D(
                textComponent: TextComponent(text: attributedText),
                transform: Transform(position: Vector3(0, -500, 0))
            )
        )

        commands.insertResource(GameState())
    }
}

extension Size {
    static let spriteSize: Size = Size(width: 64, height: 64)
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
func OnCollide(
    _ commands: Commands,
    _ events: Events<CollisionEvents.Began>
) {
    for event in events {
        if let bullet = event.entityB.components[Bullet.self],
            var enemy = event.entityA.components[EnemyComponent.self]
        {
            enemy.health -= bullet.damage

            event.entityA.components += enemy
            commands.entity(event.entityB.id).removeFromWorld()
        }
    }
}

@System
func Movement(
    _ cameras: Query<GlobalTransform, Ref<Camera>>,
    _ players: FilterQuery<Ref<Transform>, With<PlayerComponent>>,
    _ debugOptions: ResMut<PhysicsDebugOptions>,
    _ input: Res<Input>
) {
    guard let (globalTransform, camera) = cameras.first else {
        return
    }

    if input.wrappedValue.isKeyPressed(.m) {
        debugOptions.wrappedValue = [.showPhysicsShapes, .showBoundingBoxes]
    }

    let mousePosition = input.wrappedValue.getMousePosition()
    let worldPosition =
        camera.wrappedValue.viewportToWorld2D(
            cameraGlobalTransform: globalTransform.matrix,
            viewportPosition: mousePosition
        ) ?? .zero

    players.forEach { transform in
        transform.position.x = worldPosition.x
        transform.position.y = -worldPosition.y
    }
}

struct LaserResource: Resource {
    let audio: AudioResource
}

@PlainSystem
struct FireSystem {

    @FilterQuery<Entity, Ref<Transform>, With<PlayerComponent>>
    private var players

    @Local
    private var fixedTime = FixedTimestep(stepsPerSecond: 12)

    @Res<LaserResource>
    private var laserAudio

    @Res<DeltaTime>
    private var deltaTime

    @Res<Input>
    private var input

    @Commands
    private var commands

    init(world: World) {}

    func update(context: UpdateContext) async {
        await self.players.forEach { entity, transform in
            if input.isMouseButtonPressed(.left) || input.isKeyPressed(.space) {

                let result = fixedTime.advance(with: deltaTime.deltaTime)

                if result.isFixedTick {
                    let controller = await entity.prepareAudio(self.laserAudio.audio)

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
        var collision = PhysicsBody2DComponent(
            shapes: [
                .generateBox(width: 8, height: 16)
            ],
            mass: 1,
            mode: .dynamic
        )
        collision.filter.categoryBitMask = .bullet

        commands.spawn("Bullet") { [collision] in
            Transform(position: shipTransform.position)
            Sprite(
                tintColor: .red,
                size: Size(width: 8, height: 16)
            )
            Bullet(lifetime: 4)
            collision
        }
    }
}

@PlainSystem
struct BulletSystem {

    @Query<Entity, Ref<Bullet>, Ref<PhysicsBody2DComponent>>
    private var bullets

    let bulletSpeed: Float = 400

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

    @Query<Camera>
    private var camera

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
        guard
            let camera = self.camera.first else {
            return
        }

        let viewportRect = camera.viewport.rect

        var collision = Collision2DComponent(
            shapes: [
                .generateBox(width: Size.spriteSize.width, height: Size.spriteSize.height)
            ],
            mode: .trigger
        )
        let position: Vector3 = [Float.random(in: -viewportRect.midX...viewportRect.midX), viewportRect.midY, -1]
        collision.filter.collisionBitMask = .bullet
        commands.spawn("Enemy") { [collision] in
            Transform(
                position: position
            )
            Sprite(
                texture: textureAtlas[5, 7],
                size: .spriteSize
            )
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
    let speed: Float = 200

    @Res<DeltaTime>
    private var deltaTime

    init(world: World) { }

    func update(context: UpdateContext) {
        enemies.forEach { transform in
            transform.position.y -= speed * deltaTime.deltaTime
        }
    }
}

struct ExplosionResources: Resource {
    let texture: TextureAtlas
    let audio: AudioResource
}

@PlainSystem
struct EnemyExplosionSystem {

    @Res<ExplosionResources>
    private var exposionResources

    init(world: World) { }

    @Query<Entity, EnemyComponent, Transform>
    private var enemies

    @FilterQuery<Entity, Sprite, With<ExplosionComponent>>
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
                texture[0] = self.exposionResources.texture[0, 0]
                texture[1] = self.exposionResources.texture[1, 0]
                texture[2] = self.exposionResources.texture[2, 0]
                texture[3] = self.exposionResources.texture[3, 0]
                texture[4] = self.exposionResources.texture[4, 0]
                texture[5] = self.exposionResources.texture[5, 0]

                let explosion = context.world.spawn {
                    Sprite(
                        texture: texture,
                        size: .spriteSize
                    )
                    transform
                    ExplosionComponent()
                }
                let controller = await explosion.prepareAudio(self.exposionResources.audio)
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
