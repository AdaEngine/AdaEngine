import AdaEngine

class EventListenerScene: Scene {
    
    var disposeBag: Set<AnyCancellable> = []
    
    override func sceneDidMove(to view: SceneView) {
        self.subscribe(to: SceneEvents.OnReady.self) { event in
            event.scene.physicsWorld2D?.gravity = .zero
        }
        .store(in: &self.disposeBag)
    }
}
