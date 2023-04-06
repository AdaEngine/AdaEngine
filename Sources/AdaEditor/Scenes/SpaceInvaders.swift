//
//  File.swift
//  
//
//  Created by v.prusakov on 4/6/23.
//

import AdaEngine

class SpaceInvaders {
    
    var disposeBag: Set<AnyCancellable> = []
    
    let characterAtlas: TextureAtlas
    
    init() {
        do {
            let charactersTiles = try ResourceManager.load("Assets/characters_packed.png", from: Bundle.module) as Image
            self.characterAtlas = TextureAtlas(from: charactersTiles, size: [20, 23], margin: [4, 1])
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        scene.debugOptions = [.showPhysicsShapes]
        
        let camera = OrthographicCamera()
        camera.camera.clearFlags = .solid
        camera.camera.backgroundColor = .black
        scene.addEntity(camera)
        
        try makePlayer(for: scene)
        
        // Systems
        
        scene.addSystem(MovementSystem.self)
        scene.addSystem(FireSystem.self)
        scene.addSystem(BulletSystem.self)
        
        scene.addSystem(EnemySpawnerSystem.self)
        scene.addSystem(EnemyMovementSystem.self)
        
        scene.subscribe(to: CollisionEvents.Began.self, on: nil) { event in
            print(event.entityA.name, event.entityB.name)
//            event.entityA.components[Bullet.self]
        }
        .store(in: &self.disposeBag)
        
        return scene
    }
    
    func makeGameScene() throws -> Scene {
        let startScene = Scene()
        
        return startScene
    }
    
}

extension SpaceInvaders {
    func makePlayer(for scene: Scene) throws {
        let player = Entity()
        
        player.components += Transform(scale: Vector3(0.2), position: [0, -0.85, 0])
        player.components += PlayerComponent()
        player.components += SpriteComponent(texture: characterAtlas[7, 1])
        player.components += Collision2DComponent(shapes: [.generateBox(width: 0.2, height: 0.2)], mode: .trigger)
        
        scene.addEntity(player)
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
    
    let fixedTime = FixedTimestep(stepsPerSecond: 24)
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.player).forEach { entity in
            let transform = entity.components[Transform.self]!
            
            if Input.isMouseButtonPressed(.left) || Input.isKeyPressed(.space) {
                let result = fixedTime.advance(with: context.deltaTime)
                
                if result.isFixedTick {
                    fireBullet(context: context, shipTransform: transform)
                }
            }
        }
    }
    
    func fireBullet(context: UpdateContext, shipTransform: Transform) {
        let bullet = Entity()
        
        let bulletScale = Vector3(0.02, 0.04, 1)
        
        bullet.components += Transform(scale: bulletScale, position: shipTransform.position)
        bullet.components += SpriteComponent(tintColor: .red)
        bullet.components += Bullet(lifetime: 4)
        bullet.components += Collision2DComponent(shapes: [.generateBox(width: bulletScale.x, height: bulletScale.y)], mode: .trigger)
        
        context.scene.addEntity(bullet)
    }
}

struct Bullet: Component {
    var damage: Float = 30
    let lifetime: Float
    var currentLifetime: Float = 0
}

struct BulletSystem: System {
    
    static let bullet = EntityQuery(where: .has(Bullet.self))
    static let bulletSpeed: Float = 3
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.bullet).forEach { entity in
            var (bullet, transform) = entity.components[Bullet.self, Transform.self]
            
            transform.position.y += Self.bulletSpeed * context.deltaTime
            bullet.currentLifetime += context.deltaTime
            
            if bullet.lifetime > bullet.currentLifetime {
                entity.components += bullet
                entity.components += transform
            } else {
                entity.removeFromScene()
            }
        }
    }
}

struct EnemyComponent: Component {
    var health: Float
    let lifetime: Float
    var currentLifetime: Float = 0
}

struct EnemySpawnerSystem: System {
    
    let fixedTime = FixedTimestep(stepsPerSecond: 1)
    
    let textureAtlas: TextureAtlas
    
    init(scene: Scene) {
        do {
            let tiles = try ResourceManager.load("Assets/tiles_packed.png", from: Bundle.module) as Image
            
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
        entity.components += Collision2DComponent(shapes: [.generateBox(width: 0.25, height: 0.25)], mode: .trigger)
        entity.components += EnemyComponent(health: 100, lifetime: 5)
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
    static let speed: Float = 0.3
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.enemy).forEach { entity in
            var transform = entity.components[Transform.self]!
            transform.position.y -= Self.speed * context.deltaTime
            entity.components += transform
        }
    }
}
