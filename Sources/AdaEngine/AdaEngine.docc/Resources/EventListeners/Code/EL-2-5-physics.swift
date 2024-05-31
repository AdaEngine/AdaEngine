import AdaEngine

class EventListenerScene {
    
    var disposeBag: Set<AnyCancellable> = []
    
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        scene.subscribe(to: SceneEvents.OnReady.self) { event in
            event.scene.physicsWorld2D?.gravity = .zero
        }.store(in: &self.disposeBag)
        
        return scene
    }
}
