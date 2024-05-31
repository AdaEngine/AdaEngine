import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        self.addEntity(cameraEntity)
        
        let spriteSheetImage = try ResourceManager.loadSync("characters_packed.png", from: Bundle.main) as Image
        let spriteSheet = TextureAtlas(from: spriteSheetImage, size: [20, 23], margin: [4, 1])
        
        let playerEntity = Entity(name: "Player")
        playerEntity.components += SpriteComponent(texture: spriteSheet[7, 1])
        playerEntity.components += Transform(scale: Vector3(0.19))
        playerEntity.components += PlayerComponent()
        self.addEntity(playerEntity)
        
        self.addSystem(MovementSystem.self)
    }
}

@Component
struct PlayerComponent {}

struct MovementSystem: System {
    
    private static let playerQuery = EntityQuery(where: .has(PlayerComponent.self) && .has(Transform.self))
    
    let speed: Float = 3
    
    init(scene: Scene) { }
    
    func update(context: UpdateContext) {
        
    }
}
