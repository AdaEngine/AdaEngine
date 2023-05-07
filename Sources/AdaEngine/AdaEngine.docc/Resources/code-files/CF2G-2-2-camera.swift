import AdaEngine

class FirstScene {
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        scene.addEntity(cameraEntity)
        
        return scene
    }
}
