import AdaEngine

@main
struct UIBasicsApp: App {
    var body: some AppScene {
        WindowGroup {
            ContentView()
                ._debugDrawing(.drawViewOverlays)
        }
        .windowMode(.windowed)
        .windowTitle("UI Basics")
    }
}
