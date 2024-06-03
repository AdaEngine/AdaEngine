import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        /** Collapsed code */
    }
}

@Component
struct PlayerComponent {}

struct MovementSystem: System {
    
    private static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(Transform.self))
    
    let speed: Float = 3
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.playerQuery).forEach { entity in
            var transform = entity.components[Transform.self]!
        }
    }
}
