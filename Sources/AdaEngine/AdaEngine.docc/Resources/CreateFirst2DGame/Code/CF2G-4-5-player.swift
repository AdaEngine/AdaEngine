import AdaEngine

class FirstScene {
    func makeScene() throws -> Scene {
        /** Collapsed code */
    }
}

struct PlayerComponent: Component {}

struct MovementSystem: System {
    
    private static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(Transform.self))
    
    let speed: Float = 3
    
    init(scene: Scene) {
        
    }
    
    func update(context: UpdateContext) {
        context.scene.performQuery(Self.playerQuery)
    }
}
