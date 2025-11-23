////
////  SpaceInvaders.swift
////  AdaEngine
////
////  Created by v.prusakov on 4/6/23.
////
//
//import AdaEngine
//
///// FIXME: This scene has a bug with animated texture. They doesn't dispawned correctly..
//
//class SpaceInvaders: Scene, @unchecked Sendable {
//
//    var disposeBag: Set<AnyCancellable> = []
//    var characterAtlas: TextureAtlas!
//    
//    override func sceneDidMove(to view: SceneView) {
////        let sound = try! AssetsManager.loadSync("Assets/WindlessSlopes.wav", from: Bundle.editor) as AudioResource
//        let charactersTiles = try! AssetsManager.loadSync(
//            Image.self, 
//            at: "Assets/characters_packed.png", 
//            from: Bundle.editor
//        ).asset
//        self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
//        
//        let camera = OrthographicCamera()
//        camera.camera.clearFlags = .solid
//        camera.camera.backgroundColor = .black
////        camera.prepareAudio(sound)
////            .setLoop(true)
////            .setVolume(0.6)
////            .play()
//
//        self.world.addEntity(camera)
//
//        try! self.makePlayer()
//        try! self.makeScore()
//
//        // Systems
//
//        self.world.addSystem(MovementSystem.self)
//        self.world.addSystem(FireSystem.self)
//        self.world.addSystem(BulletSystem.self)
//
//        self.world.addSystem(EnemySpawnerSystem.self)
//        self.world.addSystem(EnemyMovementSystem.self)
//        self.world.addSystem(EnemyLifetimeSystem.self)
//        self.world.addSystem(EnemyExplosionSystem.self)
//
//        self.world.addSystem(ScoreSystem.self)
//
//        self.subscribe(to: CollisionEvents.Began.self) { event in
//            if let bullet = event.entityB.components[Bullet.self], var enemy = event.entityA.components[EnemyComponent.self] {
//                enemy.health -= bullet.damage
//
//                event.entityA.components += enemy
//                event.entityB.removeFromWorld()
//            }
//        }
//        .store(in: &self.disposeBag)
//
//        self.subscribe(to: SceneEvents.OnReady.self) { event in
//            Task { @MainActor in
//                event.scene.world.physicsWorld2D?.gravity = .zero
//            }
//        }.store(in: &self.disposeBag)
//    }
//
//    private func makePlayer() throws {
//        let player = Entity()
//
//        player.components += Transform(scale: Vector3(0.2), position: [0, -0.85, 0])
//        player.components += PlayerComponent()
//        player.components += SpriteComponent(texture: characterAtlas[7, 1])
//
//        self.world.addEntity(player)
//    }
//    
//    private func makeScore() throws {
//        var container = TextAttributeContainer()
//        container.foregroundColor = .white
//        let attributedText = AttributedText("Score: 0", attributes: container)
//
//        let score = Entity(name: "Score") {
//            Text2DComponent(text: attributedText)
//            GameState()
//            Transform(scale: Vector3(0.1), position: [-0.2, -0.9, 0])
//            NoFrustumCulling()
//        }
//
//        self.world.addEntity(score)
//    }
//}
//
//@System
//struct MovementSystem {
//
//    static let camera = EntityQuery(where: .has(Camera.self))
//    static let player = EntityQuery(where: .has(PlayerComponent.self))
//
//    @Res<Input>
//    private var input
//
//    init(world: World) { }
//
//    func update(context: UpdateContext) {
//        let cameraEntity = context.world.performQuery(Self.camera).first!
//        let camera = cameraEntity.components[Camera.self]!
//        guard let globalTransform = cameraEntity.components[GlobalTransform.self]?.matrix else {
//            return
//        }
//
//        let mousePosition = input.getMousePosition()
//
//        let worldPosition = camera.viewportToWorld2D(cameraGlobalTransform: globalTransform, viewportPosition: mousePosition) ?? .zero
//
//        context.world.performQuery(Self.player).forEach { entity in
//            var transform = entity.components[Transform.self]!
//            transform.position.x = worldPosition.x
//            transform.position.y = -worldPosition.y
//
//            entity.components += transform
//        }
//    }
//}
//
//struct FireSystem: System {
//
//    static let player = EntityQuery(where: .has(PlayerComponent.self))
//
//    @LocalIsolated private var fixedTime = FixedTimestep(stepsPerSecond: 12)
//    let laserAudio: AudioResource
//
//    @Res<DeltaTime>
//    private var deltaTime
//
//    @Res<Input>
//    private var input
//
//    init(world: World) {
//        self.laserAudio = try! AssetsManager.loadSync(
//            AudioResource.self, 
//            at: "Assets/laserShoot.wav", 
//            from: .editor
//        ).asset
//    }
//
//    func update(context: UpdateContext) {
//        context.world.performQuery(Self.player).forEach { entity in
//            let transform = entity.components[Transform.self]!
//
//            if input.isMouseButtonPressed(.left) || input.isKeyPressed(.space) {
//
//                let result = fixedTime.advance(with: deltaTime.deltaTime)
//
//                if result.isFixedTick {
//                    let controller = entity.prepareAudio(self.laserAudio)
//
//                    if controller.isPlaying {
//                        controller.stop()
//                    }
//
//                    controller.volume = 0.15
//                    controller.play()
//
//                    fireBullet(context: context, shipTransform: transform)
//                }
//            }
//        }
//    }
//
//    func fireBullet(context: borrowing UpdateContext, shipTransform: Transform) {
//        let bullet = Entity(name: "Bullet")
//
//        let bulletScale = Vector3(0.02, 0.04, 0.04)
//
//        bullet.components += Transform(scale: bulletScale, position: shipTransform.position)
//        bullet.components += SpriteComponent(tintColor: .red)
//        bullet.components += Bullet(lifetime: 4)
//
//        var collision = PhysicsBody2DComponent(
//            shapes: [
//                .generateBox()
//            ],
//            mass: 1,
//            mode: .dynamic
//        )
//
//        collision.filter.categoryBitMask = .bullet
//        bullet.components += collision
//        context.world.addEntity(bullet)
//    }
//}
//
//@Component
//struct Bullet {
//    var damage: Float = 30
//    let lifetime: Float
//    var currentLifetime: Float = 0
//}
//
//@System
//struct BulletSystem {
//
//    static let bullet = EntityQuery(where: .has(Bullet.self) && .has(PhysicsBody2DComponent.self))
//    static let bulletSpeed: Float = 3
//
//    @Res<DeltaTime>
//    private var deltaTime
//
//    init(world: World) { }
//
//    func update(context: UpdateContext) {
//        context.world.performQuery(Self.bullet).forEach { entity in
//            var (bullet, body) = entity.components[Bullet.self, PhysicsBody2DComponent.self]
//
//            body.linearVelocity = [0, Self.bulletSpeed]
//            bullet.currentLifetime += deltaTime.deltaTime
//
//            if bullet.lifetime > bullet.currentLifetime {
//                entity.components += bullet
//            } else {
//                entity.removeFromWorld()
//            }
//        }
//    }
//}
//
//@Component
//struct EnemyComponent {
//    var health: Float
//    let lifetime: Float
//    var currentLifetime: Float = 0
//}
//
//@System
//struct EnemySpawnerSystem {
//
//    @LocalIsolated
//    private var fixedTime = FixedTimestep(stepsPerSecond: 2)
//
//    let textureAtlas: TextureAtlas
//
//    @Res<DeltaTime>
//    private var deltaTime
//
//    init(world: World) {
//        do {
//            let tiles = try AssetsManager.loadSync(
//                Image.self, 
//                at: "Assets/tiles_packed.png", 
//                from: Bundle.editor
//            ).asset
//
//            self.textureAtlas = TextureAtlas(from: tiles, size: [18, 18])
//        } catch {
//            fatalError(error.localizedDescription)
//        }
//    }
//
//    func update(context: UpdateContext) {
//        let result = fixedTime.advance(with: deltaTime.deltaTime)
//
//        if result.isFixedTick {
//            self.spawnEnemy(context: context)
//        }
//    }
//
//    func spawnEnemy(context: borrowing UpdateContext) {
//        let entity = Entity(name: "Enemy")
//
//        var transform = Transform()
//        transform.scale = Vector3(0.25)
//        transform.position = [Float.random(in: -1.8...1.8), 1, -1]
//        entity.components += transform
//        entity.components += SpriteComponent(texture: textureAtlas[5, 7])
//
//        var collision = Collision2DComponent(
//            shapes: [
//                .generateBox()
//            ],
//            mode: .trigger
//        )
//
//        collision.filter.collisionBitMask = .bullet
//
//        entity.components += collision
//        entity.components += EnemyComponent(health: 100, lifetime: 12)
//        context.world.addEntity(entity)
//    }
//}
//
//@System
//struct EnemyLifetimeSystem {
//    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))
//
//    @Res<DeltaTime>
//    private var deltaTime
//
//    init(world: World) { }
//
//    func update(context: UpdateContext) {
//        context.world.performQuery(Self.enemy).forEach { entity in
//            var enemy = entity.components[EnemyComponent.self]!
//
//            enemy.currentLifetime += deltaTime.deltaTime
//
//            if enemy.lifetime > enemy.currentLifetime {
//                entity.components += enemy
//            } else {
//                entity.removeFromWorld()
//            }
//        }
//    }
//}
//
//struct EnemyMovementSystem: System {
//
//    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))
//    static let speed: Float = 0.1
//
//    @Res<DeltaTime>
//    private var deltaTime
//
//    init(world: World) { }
//
//    func update(context: UpdateContext) {
//        context.world.performQuery(Self.enemy).forEach { entity in
//            var transform = entity.components[Transform.self]!
//            transform.position.y -= Self.speed * deltaTime.deltaTime
//            entity.components += transform
//        }
//    }
//}
//
//extension CollisionGroup {
//    static let bullet = CollisionGroup(rawValue: 1 << 2)
//}
//
//@Component
//struct ExplosionComponent { }
//
//struct EnemyExplosionSystem: System {
//
//    let exposionAtlas: TextureAtlas
//    let explosionAudio: AudioResource
//
//    init(world: World) {
//        do {
//            let image = try AssetsManager.loadSync(
//                Image.self, 
//                at: "Assets/explosion.png", 
//                from: .editor
//            ).asset
//            self.exposionAtlas = TextureAtlas(from: image, size: SizeInt(width: 32, height: 32))
//
//            self.explosionAudio = try AssetsManager.loadSync(
//                AudioResource.self, 
//                at: "Assets/explosion-1.wav", 
//                from: .editor
//            ).asset
//        } catch {
//            fatalError("Can't load assets \(error)")
//        }
//    }
//
//    static let enemy = EntityQuery(where: .has(EnemyComponent.self) && .has(Transform.self))
//    static let explosions = EntityQuery(where: .has(ExplosionComponent.self))
//    static let scores = EntityQuery(where: .has(GameState.self))
//
//    func update(context: UpdateContext) {
//        let scores = context.world.performQuery(Self.scores).first
//
//        // Make expolosions
//        context.world.performQuery(Self.enemy).forEach { entity in
//            let (enemy, transform) = entity.components[EnemyComponent.self, Transform.self]
//
//            if enemy.health <= 0 {
//                scores?.components[GameState.self]?.score += 1
//
//                let texture = AnimatedTexture()
//                texture.framesPerSecond = 6
//                texture.framesCount = 6
//                texture.options = []
//                texture[0] = self.exposionAtlas[0, 0]
//                texture[1] = self.exposionAtlas[1, 0]
//                texture[2] = self.exposionAtlas[2, 0]
//                texture[3] = self.exposionAtlas[3, 0]
//                texture[4] = self.exposionAtlas[4, 0]
//                texture[5] = self.exposionAtlas[5, 0]
//
//                let explosion = Entity()
//                let controller = explosion.prepareAudio(self.explosionAudio)
//                controller.volume = 0.4
//                controller.play()
//
//                explosion.components += SpriteComponent(texture: texture)
//                explosion.components += transform
//                explosion.components += ExplosionComponent()
//                context.world.addEntity(explosion)
//
//                entity.removeFromWorld()
//            }
//        }
//
//        // Remove explosions
//        context.world.performQuery(Self.explosions).forEach { entity in
//            guard let texture = entity.components[SpriteComponent.self]?.texture as? AnimatedTexture else {
//                return
//            }
//
//            if texture.isPaused {
//                entity.removeFromWorld()
//            }
//        }
//    }
//}
//
//@Component
//struct GameState {
//    var score: Int = 0
//}
//
//struct ScoreSystem: System {
//
//    static let scores = EntityQuery(where: .has(Text2DComponent.self) && .has(GameState.self))
//
//    var container: TextAttributeContainer
//
//    init(world: World) {
//        self.container = TextAttributeContainer()
//        self.container.foregroundColor = .white
//    }
//
//    func update(context: UpdateContext) {
//        for entity in context.world.performQuery(Self.scores) {
//            var (text, score) = entity.components[Text2DComponent.self, GameState.self]
//            text.text = AttributedText("Score: \(score.score)", attributes: self.container)
//            entity.components += text
//        }
//    }
//}
