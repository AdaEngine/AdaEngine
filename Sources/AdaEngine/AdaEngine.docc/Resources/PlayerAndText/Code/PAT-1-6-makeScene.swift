import AdaEngine

class PlayerAndTextScene: Scene {
    override func sceneDidMove(to view: SceneView) {
        try self.makePlayer(for: self)
    }
}
