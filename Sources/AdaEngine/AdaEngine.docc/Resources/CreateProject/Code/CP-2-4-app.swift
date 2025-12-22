import AdaEngine

@main
struct FirstPackageApp: App {
    var body: some AppScene {
        DefaultAppWindow()
            .windowMode(.windowed)
            .windowTitle("First Ada App")
    }
}
