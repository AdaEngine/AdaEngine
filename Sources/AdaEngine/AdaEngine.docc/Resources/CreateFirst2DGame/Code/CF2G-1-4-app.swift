import AdaEngine

@main
struct FirstPackageApp: App {
    
    var scene: some AppScene {
        GameAppScene {
            FirstScene()
        }
        .windowMode(.windowed)
        .windowTitle("First Ada App")
    }
}
