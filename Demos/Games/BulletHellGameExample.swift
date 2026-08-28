//
//  BulletHellGameExample.swift
//  AdaEngine
//
//  Move with mouse or WASD, fire with Space or left click.
//
// swiftlint:disable file_length

import AdaEngine
import Foundation

private enum GameTuning {
    static let playfieldHalfWidth: Float = 500
    static let playfieldHalfHeight: Float = 460
    static let backgroundScrollSpeed: Float = 5
    static let backgroundTileSize: Float = 144
    static let backgroundMargin: Float = 24
    static let hudHeight: Float = 108
    static let playerFireRate = 12
    static let enemySpawnInterval: Float = 2.8
    static let maximumEnemies = 4
}

@main
struct BulletHellGameApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(BulletHellPlugin())
            .windowMode(.windowed)
    }
}

@MainActor
private struct BulletHellPlugin: Plugin {
    func setup(in app: borrowing AppWorlds) {
        app
            .addSystem(SetupSceneSystem.self, on: .startup)
            .addSystem(BackgroundScrollSystem.self)
            .addSystem(PlayerMovementSystem.self)
            .addSystem(PlayerFireSystem.self)
            .addSystem(PlayerProjectileSystem.self)
            .addSystem(EnemySpawnerSystem.self)
            .addSystem(EnemyMovementSystem.self)
            .addSystem(EnemyFireSystem.self)
            .addSystem(EnemyProjectileSystem.self)
            .addSystem(PlayerProjectileHitSystem.self)
            .addSystem(EnemyDestructionSystem.self)
            .addSystem(SupplyDropSystem.self)
            .addSystem(PickupSystem.self)
            .addSystem(EffectParticleSystem.self)
            .addSystem(GameLifecycleSystem.self)
            .addSystem(HUDLayoutSystem.self)
            .addSystem(HUDSystem.self)
            .insertResource(GameState())
    }
}

private struct SpriteAtlases: Resource {
    let ships: TextureAtlas
    let tiles: TextureAtlas
}

@Component
struct PlayerComponent { }

@Component
struct BackgroundTile {
    let horizontalAnchor: Float
    let verticalPhase: Float
    let localX: Float
    let localY: Float
}

@Component
struct PlayerProjectile {
    let velocity: Vector2
    let damage: Float
    let lifetime: Float
    var age: Float = 0
}

@Component
struct EnemyProjectile {
    let velocity: Vector2
    let damage: Float
    let lifetime: Float
    var age: Float = 0
}

@Component
struct EnemyShip {
    var health: Float = 90
    var fireCooldown: Float
    var phase: Float
    var volley: Int = 0
}

@Component
struct Pickup {
    let isRepair: Bool
    var age: Float = 0
}

@Component
struct EffectParticle {
    let velocity: Vector2
    let color: Color
    let lifetime: Float
    var age: Float = 0
}

@Component
struct ScoreLabel { }

@Component
struct StatusLabel { }

@Component
struct HUDHealthBar { }

@Component
struct HUDBackdrop { }

@Component
struct HUDSlot {
    let kind: Int

    static let score = 0
    static let status = 1
    static let hint = 2
    static let healthBackground = 3
    static let healthFill = 4
    static let backdrop = 5
}

struct GameState: Resource {
    var score = 0
    var health: Float = 100
    var powerLevel = 1
    var invulnerability: Float = 0
    var nextSupplyDrop: Float = 10
}

@PlainSystem
struct SetupSceneSystem {
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) async {
        guard let shipImage = try? await AssetsManager.load(
            Image.self,
            at: "Resources/ships_packed.png",
            from: .module
        ).asset,
        let tileImage = try? await AssetsManager.load(
            Image.self,
            at: "Resources/tiles_packed.png",
            from: .module
        ).asset else {
            assertionFailure("Unable to load the bullet-hell sprite atlases.")
            return
        }
        let atlases = SpriteAtlases(
            ships: TextureAtlas(from: shipImage, size: [32, 32]),
            tiles: TextureAtlas(from: tileImage, size: [16, 16])
        )
        commands.insertResource(atlases)

        var camera = Camera()
        camera.backgroundColor = Color.fromHex(0xDFF5F5)
        commands.spawn(bundle: Camera2D(camera: camera))

        makeLandscapeBackground(from: atlases.tiles, in: context.world)

        commands.spawn("Player ship") {
            Sprite(texture: atlases.ships[0, 0], size: Size(width: 76, height: 76))
            Transform(position: [0, -GameTuning.playfieldHalfHeight + 70, 0.2])
            PlayerComponent()
        }

        makeHUD()
    }

    private func makeLandscapeBackground(from atlas: TextureAtlas, in world: World) {
        let islands: [(origin: PointInt, horizontalAnchor: Float, verticalPhase: Float)] = [
            ([1, 3], -1, 0.25),
            ([7, 3], 1, 0.25),
            ([1, 3], -1, 0.65),
            ([7, 3], 1, 0.65)
        ]
        let islandSize = 3
        let tileSize = GameTuning.backgroundTileSize

        for island in islands {
            for row in 0..<islandSize {
                for column in 0..<islandSize {
                    let atlasRow = island.origin.y + islandSize - row - 1
                    let localX = Float(column - 1) * tileSize
                    let localY = Float(row - 1) * tileSize

                    world.spawn("Scrolling landscape tile") {
                        Sprite(
                            texture: atlas[island.origin.x + column, atlasRow],
                            size: Size(width: tileSize, height: tileSize)
                        )
                        Transform(position: [
                            localX,
                            localY,
                            0.05
                        ])
                        BackgroundTile(
                            horizontalAnchor: island.horizontalAnchor,
                            verticalPhase: island.verticalPhase,
                            localX: localX,
                            localY: localY
                        )
                    }
                }
            }
        }
    }

    // swiftlint:disable:next function_body_length
    private func makeHUD() {
        var titleAttributes = TextAttributeContainer()
        titleAttributes.foregroundColor = .white
        titleAttributes.font = .system(size: 28)

        var statusAttributes = TextAttributeContainer()
        statusAttributes.foregroundColor = .mint
        statusAttributes.font = .system(size: 22)

        var hintAttributes = TextAttributeContainer()
        hintAttributes.foregroundColor = .white.opacity(0.72)
        hintAttributes.font = .system(size: 16)

        commands.spawn("HUD backdrop") {
            Sprite(
                tintColor: Color.fromHex(0x172331).opacity(0.82),
                size: Size(width: 1, height: GameTuning.hudHeight)
            )
            Transform()
            HUDBackdrop()
            HUDSlot(kind: HUDSlot.backdrop)
        }

        commands.spawn(
            "Score",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("SCORE 0000", attributes: titleAttributes),
                    textAlignment: .leading
                ),
                transform: Transform(position: .zero)
            )
            .extend {
                ScoreLabel()
                HUDSlot(kind: HUDSlot.score)
            }
        )

        commands.spawn(
            "Status",
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("HULL 100%  •  POWER 1", attributes: statusAttributes),
                    textAlignment: .trailing
                ),
                transform: Transform(position: .zero)
            )
            .extend {
                StatusLabel()
                HUDSlot(kind: HUDSlot.status)
            }
        )

        commands.spawn(
            bundle: Text2D(
                textComponent: TextComponent(
                    text: AttributedText("MOUSE / WASD  •  FIRE: SPACE OR LEFT CLICK", attributes: hintAttributes),
                    textAlignment: .leading
                ),
                transform: Transform()
            )
            .extend { HUDSlot(kind: HUDSlot.hint) }
        )

        commands.spawn("Hull meter") {
            Sprite(tintColor: .gray.opacity(0.75), size: Size(width: 260, height: 12))
            Transform()
            HUDSlot(kind: HUDSlot.healthBackground)
        }

        commands.spawn("Hull meter fill") {
            Sprite(tintColor: .mint, size: Size(width: 260, height: 12))
            Transform()
            HUDHealthBar()
            HUDSlot(kind: HUDSlot.healthFill)
        }
    }
}

@System
func BackgroundScroll(
    _ cameras: Query<Camera>,
    _ tiles: Query<Ref<Transform>, BackgroundTile>,
    _ elapsedTime: Res<ElapsedTime>,
    _ delta: Res<DeltaTime>
) {
    guard let camera = cameras.first else {
        return
    }

    let viewportSize = camera.logicalViewport.rect.size
    guard viewportSize.width > 0, viewportSize.height > 0 else {
        return
    }

    let baseIslandSize = GameTuning.backgroundTileSize * 3
    let gap = GameTuning.backgroundMargin * 2
    let widthScale = (viewportSize.width - GameTuning.backgroundMargin * 2 - gap) / (baseIslandSize * 2)
    let heightScale = (viewportSize.height - GameTuning.hudHeight - GameTuning.backgroundMargin * 2 - gap) / (baseIslandSize * 2)
    let islandScale = min(1, max(0.1, min(widthScale, heightScale)))
    let islandHalfSize = baseIslandSize * islandScale * 0.5
    let horizontalOffset = max(0, viewportSize.width * 0.5 - islandHalfSize - GameTuning.backgroundMargin)
    let upperLimit = viewportSize.height * 0.5 + islandHalfSize
    let lowerLimit = -viewportSize.height * 0.5 - islandHalfSize
    let wrapDistance = upperLimit - lowerLimit
    let travel = (GameTuning.backgroundScrollSpeed * elapsedTime.elapsedTime * delta.wrappedValue.deltaTime)
        .truncatingRemainder(dividingBy: wrapDistance)

    tiles.forEach { transform, tile in
        var islandY = upperLimit - tile.verticalPhase * wrapDistance - travel
        if islandY < lowerLimit {
            islandY += wrapDistance
        }

        transform.scale = [islandScale, islandScale, 1]
        transform.position.x = tile.horizontalAnchor * horizontalOffset + tile.localX * islandScale
        transform.position.y = islandY + tile.localY * islandScale
    }
}

@System
func PlayerMovement(
    _ cameras: Query<GlobalTransform, Ref<Camera>>,
    _ players: FilterQuery<Ref<Transform>, With<PlayerComponent>>,
    _ input: Res<Input>,
    _ deltaTime: Res<DeltaTime>
) {
    guard let (cameraTransform, camera) = cameras.first else {
        return
    }

    let playfieldHalfExtents = playfieldHalfExtents(for: camera.wrappedValue)
    let playerTopLimit = min(
        GameTuning.playfieldHalfHeight,
        camera.wrappedValue.logicalViewport.rect.size.height * 0.5 - GameTuning.hudHeight
    ) - 40
    let mouseWorldPosition = camera.wrappedValue.viewportToWorld2D(
        cameraGlobalTransform: cameraTransform.matrix,
        viewportPosition: input.wrappedValue.getMousePosition()
    ) ?? .zero
    var keyboardDirection = Vector2.zero
    if input.wrappedValue.isKeyPressed(.a) || input.wrappedValue.isKeyPressed(.arrowLeft) { keyboardDirection.x -= 1 }
    if input.wrappedValue.isKeyPressed(.d) || input.wrappedValue.isKeyPressed(.arrowRight) { keyboardDirection.x += 1 }
    if input.wrappedValue.isKeyPressed(.w) || input.wrappedValue.isKeyPressed(.arrowUp) { keyboardDirection.y += 1 }
    if input.wrappedValue.isKeyPressed(.s) || input.wrappedValue.isKeyPressed(.arrowDown) { keyboardDirection.y -= 1 }

    players.forEach { transform in
        if keyboardDirection.squaredLength > 0 {
            let movement = keyboardDirection.normalized * (420 * deltaTime.deltaTime)
            transform.position.x += movement.x
            transform.position.y += movement.y
        } else {
            transform.position.x = mouseWorldPosition.x
            transform.position.y = -mouseWorldPosition.y
        }

        transform.position.x = min(max(transform.position.x, -playfieldHalfExtents.x + 40), playfieldHalfExtents.x - 40)
        transform.position.y = min(max(transform.position.y, -playfieldHalfExtents.y + 40), playerTopLimit)
    }
}

@System
func HUDLayout(
    _ cameras: Query<Camera>,
    _ slots: Query<Ref<Transform>, HUDSlot>,
    _ backdrops: Query<Ref<Sprite>, HUDBackdrop>
) {
    guard let camera = cameras.first else {
        return
    }

    let viewportSize = camera.logicalViewport.rect.size
    let top = viewportSize.height * 0.5 - 42
    let left = -viewportSize.width * 0.5 + 34
    let right = viewportSize.width * 0.5 - 34

    backdrops.forEach { sprite, _ in
        sprite.size = Size(width: viewportSize.width, height: GameTuning.hudHeight)
    }

    slots.forEach { transform, slot in
        switch slot.kind {
        case HUDSlot.score:
            transform.position = [left, top, 0.9]
        case HUDSlot.status:
            transform.position = [right, top, 0.9]
        case HUDSlot.hint:
            transform.position = [left, top - 46, 0.9]
        case HUDSlot.healthBackground, HUDSlot.healthFill:
            transform.position = [right - 130, top - 42, 0.85]
        case HUDSlot.backdrop:
            transform.position = [0, viewportSize.height * 0.5 - GameTuning.hudHeight * 0.5, 0.8]
        default:
            break
        }
    }
}

@PlainSystem
struct PlayerFireSystem {
    @FilterQuery<Ref<Transform>, With<PlayerComponent>>
    private var players
    @Res<GameState>
    private var state
    @Res<DeltaTime>
    private var deltaTime
    @Res<Input>
    private var input
    @Commands
    private var commands
    @Local
    private var fireTimer = FixedTimestep(stepsPerSecond: GameTuning.playerFireRate)
    @Res<SpriteAtlases>
    private var sprites

    init(world: World) { }

    func update(context: UpdateContext) {
        guard input.isMouseButtonPressed(.left) || input.isKeyPressed(.space),
              fireTimer.advance(with: deltaTime.deltaTime).isFixedTick
        else {
            return
        }

        players.forEach { transform in
            let offsets: [Float]
            switch state.powerLevel {
            case 3...: offsets = [-24, -12, 0, 12, 24]
            case 2: offsets = [-12, 0, 12]
            default: offsets = [0]
            }

            for offset in offsets {
                commands.spawn("Player laser") {
                    Transform(position: [transform.position.x + offset, transform.position.y + 38, 0.4])
                    Sprite(texture: sprites.tiles[0, 0], size: Size(width: 7, height: 22))
                    PlayerProjectile(velocity: [offset * 0.5, 680], damage: 30, lifetime: 1.6)
                }
            }
        }
    }
}

@PlainSystem
struct PlayerProjectileSystem {
    @Query<Camera>
    private var cameras
    @Query<Entity, Ref<PlayerProjectile>, Ref<Transform>>
    private var projectiles
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)

        projectiles.forEach { entity, projectile, transform in
            transform.position.x += projectile.wrappedValue.velocity.x * deltaTime.deltaTime
            transform.position.y += projectile.wrappedValue.velocity.y * deltaTime.deltaTime
            projectile.age += deltaTime.deltaTime
            if projectile.age >= projectile.wrappedValue.lifetime || transform.position.y > playfieldHalfExtents.y + 80 {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct EnemySpawnerSystem {
    @Query<Camera>
    private var cameras
    @Query<EnemyShip>
    private var enemies
    @Res<SpriteAtlases>
    private var atlases
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands
    @Local
    private var spawnCooldown: Float = 1.5

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }

        var enemyCount = 0
        enemies.forEach { _ in enemyCount += 1 }
        spawnCooldown -= deltaTime.deltaTime
        guard spawnCooldown <= 0, enemyCount < GameTuning.maximumEnemies else {
            return
        }

        spawnCooldown = GameTuning.enemySpawnInterval
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)
        let position = Vector3(
            Float.random(in: -playfieldHalfExtents.x + 55...playfieldHalfExtents.x - 55),
            playfieldHalfExtents.y + 60,
            0.2
        )
        commands.spawn("Raider ship") {
            Sprite(texture: atlases.ships[1, 0], size: Size(width: 72, height: 72))
            Transform(rotation: Quat(axis: [0, 0, 1], angle: .pi), position: position)
            EnemyShip(fireCooldown: Float.random(in: 0.8...1.6), phase: Float.random(in: 0...(Float.pi * 2)))
        }
    }
}

@PlainSystem
struct EnemyMovementSystem {
    @Query<Camera>
    private var cameras
    @Query<Entity, Ref<EnemyShip>, Ref<Transform>>
    private var enemies
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)

        enemies.forEach { entity, enemy, transform in
            enemy.phase += deltaTime.deltaTime * 1.8
            transform.position.x += Math.sin(enemy.phase) * 48 * deltaTime.deltaTime
            transform.position.x = min(max(transform.position.x, -playfieldHalfExtents.x + 40), playfieldHalfExtents.x - 40)
            transform.position.y -= 42 * deltaTime.deltaTime
            if transform.position.y < -playfieldHalfExtents.y - 100 {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct EnemyFireSystem {
    @Query<Ref<EnemyShip>, Transform>
    private var enemies
    @FilterQuery<Transform, With<PlayerComponent>>
    private var players
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands
    @Res<SpriteAtlases>
    private var sprites

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let playerTransform = players.first else {
            return
        }

        enemies.forEach { enemy, transform in
            enemy.fireCooldown -= deltaTime.deltaTime
            guard enemy.fireCooldown <= 0 else {
                return
            }

            enemy.volley += 1
            enemy.fireCooldown = enemy.volley.isMultiple(of: 3) ? 1.55 : 1.05
            let aimedDirection = Vector2(
                playerTransform.position.x - transform.position.x,
                playerTransform.position.y - transform.position.y
            ).normalized
            let projectileCount = enemy.volley.isMultiple(of: 3) ? 7 : 3
            let step: Float = projectileCount == 7 ? 0.16 : 0.23
            let firstAngle = -step * Float(projectileCount - 1) / 2

            for index in 0..<projectileCount {
                let direction = rotated(aimedDirection, by: firstAngle + Float(index) * step)
                commands.spawn("Enemy plasma") {
                    Transform(position: [transform.position.x, transform.position.y - 34, 0.4])
                    Sprite(texture: sprites.tiles[0, 0], tintColor: .pink, size: Size(width: 13, height: 13))
                    EnemyProjectile(velocity: direction * 260, damage: 12, lifetime: 4.2)
                }
            }
        }
    }
}

@PlainSystem
struct EnemyProjectileSystem {
    @Query<Camera>
    private var cameras
    @Query<Entity, Ref<EnemyProjectile>, Ref<Transform>>
    private var projectiles
    @FilterQuery<Transform, With<PlayerComponent>>
    private var players
    @ResMut<GameState>
    private var state
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first, let playerTransform = players.first else {
            return
        }
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)

        projectiles.forEach { entity, projectile, transform in
            transform.position.x += projectile.wrappedValue.velocity.x * deltaTime.deltaTime
            transform.position.y += projectile.wrappedValue.velocity.y * deltaTime.deltaTime
            projectile.age += deltaTime.deltaTime
            if isWithinRadius(transform.position, playerTransform.position, radius: 28), state.invulnerability <= 0 {
                state.health -= projectile.wrappedValue.damage
                state.invulnerability = 0.45
                commands.entity(entity.id).removeFromWorld()
                spawnImpact(at: playerTransform.position)
            } else if projectile.age >= projectile.wrappedValue.lifetime || isOutsidePlayfield(transform.position, halfExtents: playfieldHalfExtents) {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }

    private func spawnImpact(at position: Vector3) {
        for index in 0..<8 {
            let angle = Float(index) * Float.pi * 2 / 8
            commands.spawn("Player impact") {
                Transform(position: position)
                Sprite(tintColor: .pink, size: Size(width: 7, height: 7))
                EffectParticle(
                    velocity: [Math.cos(angle) * 145, Math.sin(angle) * 145],
                    color: .pink,
                    lifetime: 0.3
                )
            }
        }
    }
}

@PlainSystem
struct PlayerProjectileHitSystem {
    @Query<Entity, Ref<PlayerProjectile>, Transform>
    private var playerProjectiles
    @Query<Entity, Ref<EnemyShip>, Transform>
    private var enemies
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        playerProjectiles.forEach { projectileEntity, projectile, projectileTransform in
            var didHitEnemy = false
            enemies.forEach { _, enemy, enemyTransform in
                guard !didHitEnemy, isWithinRadius(projectileTransform.position, enemyTransform.position, radius: 38) else {
                    return
                }

                enemy.health -= projectile.wrappedValue.damage
                didHitEnemy = true
                commands.entity(projectileEntity.id).removeFromWorld()
                commands.spawn("Hull spark") {
                    Transform(position: enemyTransform.position)
                    Sprite(tintColor: .yellow, size: Size(width: 13, height: 13))
                    EffectParticle(velocity: [0, 50], color: .yellow, lifetime: 0.22)
                }
            }
        }
    }
}

@PlainSystem
struct EnemyDestructionSystem {
    @Query<Entity, EnemyShip, Transform>
    private var enemies
    @ResMut<GameState>
    private var state
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        enemies.forEach { entity, enemy, transform in
            guard enemy.health <= 0 else {
                return
            }

            state.score += 100
            commands.entity(entity.id).removeFromWorld()
            spawnExplosion(at: transform.position)
            let pickupRoll = Int.random(in: 0..<100)
            if pickupRoll < 24 {
                spawnPickup(at: transform.position, isRepair: pickupRoll < 8)
            }
        }
    }

    private func spawnExplosion(at position: Vector3) {
        for index in 0..<18 {
            let angle = Float(index) * Float.pi * 2 / 18
            let speed = Float.random(in: 80...230)
            let color: Color = index.isMultiple(of: 2) ? .orange : .yellow
            commands.spawn("Ship explosion") {
                Transform(position: position)
                Sprite(tintColor: color, size: Size(width: 10, height: 10))
                EffectParticle(
                    velocity: [Math.cos(angle) * speed, Math.sin(angle) * speed],
                    color: color,
                    lifetime: Float.random(in: 0.35...0.7)
                )
            }
        }
    }

    private func spawnPickup(at position: Vector3, isRepair: Bool) {
        let color: Color = isRepair ? .green : .mint
        commands.spawn(isRepair ? "Repair cell" : "Power cell") {
            Transform(position: position)
            Sprite(tintColor: color, size: Size(width: 24, height: 24))
            Pickup(isRepair: isRepair)
        }
    }
}

@PlainSystem
struct SupplyDropSystem {
    @Query<Camera>
    private var cameras
    @ResMut<GameState>
    private var state
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands
    @Res<SpriteAtlases>
    private var sprites

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first else {
            return
        }

        state.nextSupplyDrop -= deltaTime.deltaTime
        guard state.nextSupplyDrop <= 0 else {
            return
        }

        state.nextSupplyDrop = 13
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)
        let position = Vector3(
            Float.random(in: -playfieldHalfExtents.x + 40...playfieldHalfExtents.x - 40),
            playfieldHalfExtents.y,
            0.3
        )
        commands.spawn("Scheduled repair cell") {
            Transform(position: position)
            Sprite(texture: sprites.tiles[0, 2], size: Size(width: 26, height: 26))
            Pickup(isRepair: true)
        }
    }
}

@PlainSystem
struct PickupSystem {
    @Query<Camera>
    private var cameras
    @Query<Entity, Ref<Pickup>, Ref<Transform>>
    private var pickups
    @FilterQuery<Transform, With<PlayerComponent>>
    private var players
    @ResMut<GameState>
    private var state
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        guard let camera = cameras.first, let playerTransform = players.first else {
            return
        }
        let playfieldHalfExtents = playfieldHalfExtents(for: camera)

        pickups.forEach { entity, pickup, transform in
            pickup.age += deltaTime.deltaTime
            transform.position.y -= 65 * deltaTime.deltaTime
            transform.rotation = Quat(axis: [0, 0, 1], angle: pickup.age * 4)
            if isWithinRadius(transform.position, playerTransform.position, radius: 35) {
                if pickup.wrappedValue.isRepair {
                    state.health = min(100, state.health + 30)
                } else {
                    state.powerLevel = min(3, state.powerLevel + 1)
                }
                commands.entity(entity.id).removeFromWorld()
            } else if pickup.age > 8 || transform.position.y < -playfieldHalfExtents.y - 60 {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@PlainSystem
struct EffectParticleSystem {
    @Query<Entity, Ref<EffectParticle>, Ref<Transform>, Ref<Sprite>>
    private var particles
    @Res<DeltaTime>
    private var deltaTime
    @Commands
    private var commands

    init(world: World) { }

    func update(context: UpdateContext) {
        particles.forEach { entity, particle, transform, sprite in
            particle.age += deltaTime.deltaTime
            transform.position.x += particle.wrappedValue.velocity.x * deltaTime.deltaTime
            transform.position.y += particle.wrappedValue.velocity.y * deltaTime.deltaTime
            let remaining = max(0, 1 - particle.age / particle.wrappedValue.lifetime)
            transform.scale = Vector3(remaining)
            sprite.tintColor = particle.wrappedValue.color.opacity(remaining)
            if particle.age >= particle.wrappedValue.lifetime {
                commands.entity(entity.id).removeFromWorld()
            }
        }
    }
}

@System
func GameLifecycle(
    _ state: ResMut<GameState>,
    _ deltaTime: Res<DeltaTime>
) {
    state.invulnerability = max(0, state.invulnerability - deltaTime.deltaTime)
    if state.health <= 0 {
        state.health = 100
        state.powerLevel = 1
        state.score = max(0, state.score - 250)
    }
}

@System
func HUD(
    _ scoreLabels: Query<Ref<TextComponent>, ScoreLabel>,
    _ statusLabels: Query<Ref<TextComponent>, StatusLabel>,
    _ healthBars: Query<Ref<Transform>, HUDHealthBar>,
    _ state: Res<GameState>
) {
    var scoreAttributes = TextAttributeContainer()
    scoreAttributes.foregroundColor = .white
    scoreAttributes.font = .system(size: 28)

    var statusAttributes = TextAttributeContainer()
    statusAttributes.foregroundColor = state.health <= 35 ? .pink : .mint
    statusAttributes.font = .system(size: 22)

    scoreLabels.forEach { text, _ in
        text.text = AttributedText(String(format: "SCORE %04d", state.score), attributes: scoreAttributes)
    }
    statusLabels.forEach { text, _ in
        text.text = AttributedText(
            String(format: "HULL %03.0f%%  •  POWER %d", state.health, state.powerLevel),
            attributes: statusAttributes
        )
    }
    healthBars.forEach { transform, _ in
        transform.scale.x = max(0.05, state.health / 100)
    }
}

private func rotated(_ vector: Vector2, by angle: Float) -> Vector2 {
    Vector2(
        vector.x * Math.cos(angle) - vector.y * Math.sin(angle),
        vector.x * Math.sin(angle) + vector.y * Math.cos(angle)
    )
}

private func isWithinRadius(_ first: Vector3, _ second: Vector3, radius: Float) -> Bool {
    let delta = Vector2(first.x - second.x, first.y - second.y)
    return delta.squaredLength <= radius * radius
}

private func playfieldHalfExtents(for camera: Camera) -> Vector2 {
    let viewportHalfExtents = camera.logicalViewport.rect.size.asVector2 * 0.5
    return [
        min(GameTuning.playfieldHalfWidth, max(100, viewportHalfExtents.x)),
        min(GameTuning.playfieldHalfHeight, max(100, viewportHalfExtents.y))
    ]
}

private func isOutsidePlayfield(_ position: Vector3, halfExtents: Vector2) -> Bool {
    abs(position.x) > halfExtents.x + 100 || abs(position.y) > halfExtents.y + 100
}
// swiftlint:enable file_length
