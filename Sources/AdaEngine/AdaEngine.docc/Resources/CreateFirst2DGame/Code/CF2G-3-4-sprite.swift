import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        self.world.addEntity(cameraEntity)
        
        let spriteSheetImage = try AssetsManager.loadSync("characters_packed.png", from: Bundle.main) as Image
        let spriteSheet = TextureAtlas(from: spriteSheetImage, size: [20, 23], margin: [4, 1])
        
        let playerEntity = Entity(name: "Player")
        playerEntity.components += SpriteComponent(texture: spriteSheet[7, 1])
        self.world.addEntity(playerEntity)
    }
}
