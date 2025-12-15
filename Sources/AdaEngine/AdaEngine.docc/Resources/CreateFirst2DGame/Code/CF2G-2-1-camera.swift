import AdaEngine

struct FirstScene: Plugin {
    func setup(in app: AppWorlds) {
        app.spawn(bundle: Camera2D())
    }
}
