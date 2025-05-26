import AdaECS

@Component
public struct DynamicScene {
    let scene: AssetHandle<Scene>
    
    public init(scene: AssetHandle<Scene>) {
        self.scene = scene
    }

    public init(world: World) {
        self.scene = AssetHandle(Scene(from: world))
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
            guard let instance else {
                insertScene(to: entity, dynamicScene: scene, world: context.world)
                return
            }
            
            if instance.identifier != scene.scene.asset.world.id {
                removeChild(from: entity)
                insertScene(to: entity, dynamicScene: scene, world: context.world)
            }
        }
    }
    
    private func insertScene(to rootEntity: Entity, dynamicScene: DynamicScene, world: World) {
        let sceneWorld = dynamicScene.scene.asset.world
        for entity in sceneWorld.getEntities() {
            rootEntity.addChild(entity)
            world.addEntity(entity)
        }
        
        for resource in sceneWorld.getResources() {
            world.insertResource(resource)
        }
        
        rootEntity.components += DynamicSceneInstance(identifier: sceneWorld.id)
    }
    
    private func removeChild(from entity: Entity) {
        for child in entity.children {
            child.removeFromScene(recursively: true)
        }
    }
}
