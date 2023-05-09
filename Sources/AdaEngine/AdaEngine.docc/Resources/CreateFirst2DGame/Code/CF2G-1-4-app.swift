import AdaEngine

@main
struct FirstPackageApp: App {
    
    let game = FirstScene()
    
    var scene: some AppScene {
        GameAppScene {
            try self.game.makeScene()
        }
        .windowMode(.windowed)
        .windowTitle("First Ada App")
    }
}
