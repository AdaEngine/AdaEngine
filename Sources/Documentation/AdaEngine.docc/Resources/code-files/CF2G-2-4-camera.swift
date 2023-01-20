import AdaEngine

class FirstScene {
    func makeScene() -> Scene {
        let scene = Scene()
        
        let cameraEntity = Entity(name: "Camera")
        
        let camera = Camera()
        camera.projection = .orthographic
        camera.isPrimal = true
        
        cameraEntity.components += camera
        scene.addEntity(cameraEntity)
        
        return scene
    }
}