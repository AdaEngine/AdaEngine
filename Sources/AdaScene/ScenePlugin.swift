import AdaApp
import AdaECS

public struct ScenePlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        app.addSystem(DynamicSceneInitSystem.self)
    }
}
