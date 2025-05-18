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
    
    init(world: World) { }
    
    func update(context: UpdateContext) {
        context.world.performQuery(Self.playerQuery).forEach { entity in
            var transform = entity.components[Transform.self]!
            
            if Input.isKeyPressed(.w) {
                transform.position.y += speed * context.deltaTime
            }
            
            if Input.isKeyPressed(.s) {
                transform.position.y -= speed * context.deltaTime
            }
            
            if Input.isKeyPressed(.a) {
                transform.position.x -= speed * context.deltaTime
            }
            
            if Input.isKeyPressed(.d) {
                transform.position.x += speed * context.deltaTime
            }
            
            entity.components += transform
        }
    }
}
