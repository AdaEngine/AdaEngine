import AdaEngine

@main
struct FirstPackageApp: App {
    var scene: some AppScene {
         EmptyWindow()
            .addPlugins(DefaultPlugins())
            .windowMode(.windowed)
            .windowTitle("First Ada App")
    }
}
