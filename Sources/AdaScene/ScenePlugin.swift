import AdaApp
import AdaECS

public struct ScenePlugin: Plugin {

    public init() {}

    public func setup(in app: AppWorlds) {
        KeyframeAnimationPlugin().setup(in: app)
        Model3DPlugin().setup(in: app)
        app.addSystem(DynamicSceneInitSystem.self)
    }
}
