import AdaEngine

@main
struct FirstPackageApp: App {
    var scene: some AppScene {
        GameAppScene {
            Scene()
        }
        .windowMode(.windowed)
        .windowTitle("First Ada App")
    }
}
