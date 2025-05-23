import AdaECS

@Component
public struct DynamicScene {
    public var entities: [Entity]
    public var resources: [any Resource]

    @MainActor
    public init(scene: Scene) {
        self.init(world: scene.world)
    }

    public init(world: World) {
        self.entities = world.getEntities()
        self.resources = world.getResources()
    }
}

@Component
public struct DynamicSceneInstance {
    let identifier: Scene.ID
}

@System
struct DynamicSceneInitSystem: System {

    @Query<DynamicScene, DynamicSceneInstance?>
    private var dynamicScenes

    init(world: World) {  }

    func update(context: UpdateContext) {
        
    }
}