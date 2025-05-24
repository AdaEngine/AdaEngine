import AdaEngine

@main
struct TileMapPhysicsApp: AdaEngineApp {
    
    var scene: SceneFunction = TileMapPhysicsScene()
    
    var body: some AppScene {
        GameScene {
            EngineSetup(appName: "TileMapPhysicsExample", bundle: .main)
        }
    }
}
