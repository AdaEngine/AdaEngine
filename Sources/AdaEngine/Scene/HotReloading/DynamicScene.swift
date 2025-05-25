import AdaECS

@Component
public struct DynamicScene {
    let worldId: World.ID
    public let entities: [Entity]
    public let resources: [any Resource]

    @MainActor
    public init(scene: Scene) {
        self.init(world: scene.world)
    }

    public init(world: World) {
        self.worldId = world.id
        self.entities = world.getEntities()
        self.resources = world.getResources()
    }
}

@Component
public struct DynamicSceneInstance {
    let identifier: World.ID
}

@System
struct DynamicSceneInitSystem: System {

    @Query<Entity, DynamicScene, DynamicSceneInstance?>
    private var dynamicScenes

    init(world: World) {  }

    func update(context: UpdateContext) {
        for (entity, scene, instance) in dynamicScenes {
            if instance == nil {
                insertScene(to: entity, dynamicScene: scene, world: context.world)
            }
        }
    }
    
    private func insertScene(to rootEntity: Entity, dynamicScene: DynamicScene, world: World) {
        for entity in dynamicScene.entities {
            rootEntity.addChild(entity)
            world.addEntity(entity)
        }
        
        for resource in dynamicScene.resources {
            world.insertResource(resource)
        }
        
        rootEntity.components += DynamicSceneInstance(identifier: dynamicScene.worldId)
    }
}
