import AdaEngine

class FirstScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        
        let cameraEntity = OrthographicCamera()
        self.world.addEntity(cameraEntity)
    }
}
