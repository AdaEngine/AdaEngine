import AdaEngine

class FirstScene {
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        scene.addEntity(cameraEntity)
        
        let spriteSheetImage = try ResourceManager.load("characters_packed.png", from: Bundle.main) as Image
        let spriteSheet = TextureAtlas(from: spriteSheetImage, size: [20, 23], margin: [4, 1])
        
        let playerEntity = Entity(name: "Player")
        scene.addEntity(playerEntity)
        
        return scene
    }
}
