import AdaEngine

@main
struct AnimatedTextApp: App {
    var body: some AppScene {
        WindowGroup {
            ContentView()
        }
        .windowMode(.windowed)
        .windowTitle("Animated Text")
    }
}
