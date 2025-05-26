import AdaECS

struct ScenePlugin: WorldPlugin {
    func setup(in world: World) {
        world.addSystem(DynamicSceneInitSystem.self)
    }
}