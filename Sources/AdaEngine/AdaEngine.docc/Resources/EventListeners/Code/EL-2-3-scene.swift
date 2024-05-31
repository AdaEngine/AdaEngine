import AdaEngine

class EventListenerScene {
    
    var disposeBag: Set<AnyCancellable> = []
    
    func makeScene() throws -> Scene {
        let scene = Scene()
        
        scene.subscribe(to: SceneEvents.OnReady.self) { event in
            // Handle event here!
        }.store(in: &self.disposeBag)
        
        return scene
    }
}
