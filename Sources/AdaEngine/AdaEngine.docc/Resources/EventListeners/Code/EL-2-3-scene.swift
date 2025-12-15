import AdaEngine

@MainActor
struct EventListenerPlugin: Plugin {
    @Local var disposeBag: Set<AnyCancellable> = []

    func setup(in app: borrowing AppWorlds) {
        app.main.subscribe(to: SceneEvents.OnReady.self) { event in
            // Handle event here!
        }
        .store(in: &self.disposeBag)
    }
}
