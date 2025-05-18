import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        
        let cameraEntity = OrthographicCamera()
        cameraEntity.camera.backgroundColor = Color(45/255, 171/255, 255/255, 1)
        self.world.addEntity(cameraEntity)
        
        let playerEntity = Entity(name: "Player")
        self.world.addEntity(playerEntity)
    }
}
