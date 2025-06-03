import AdaEngine

struct FirstScene: Plugin {
    func setup(in app: AppWorlds) {
        let cameraEntity = OrthographicCamera()
        app.addEntity(cameraEntity)
    }
}
