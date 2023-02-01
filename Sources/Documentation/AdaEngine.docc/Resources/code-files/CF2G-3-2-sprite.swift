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
        
        self.makePlayer(for: scene)
        
        return scene
    }
    
    func makePlayer(for scene: Scene) {
        let playerEntity = Entity(name: "Player")
        scene.addEntity(playerEntity)
    }
}
