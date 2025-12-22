import AdaEngine

@main
struct FirstPackageApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .addPlugins(
                FirstScene()
            )
            .windowMode(.windowed)
            .windowTitle("First Ada App")
    }
}
