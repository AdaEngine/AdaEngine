import AdaEngine

class FirstScene {
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        let cameraEntity = OrthographicCamera()
        scene.addEntity(cameraEntity)
        
        return scene
    }
}
