import AdaEngine

@main
struct FirstPackageApp: App {
    var body: some AppScene {
        EmptyWindow()
            .addPlugins(DefaultPlugins())
            .windowMode(.windowed)
            .windowTitle("First Ada App")
    }
}
