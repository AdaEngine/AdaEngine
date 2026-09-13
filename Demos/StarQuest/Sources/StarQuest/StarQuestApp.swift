import AdaEngine
import StarQuestGame

@main
struct StarQuestApp: App {
    var body: some AppScene {
        WindowGroup { StarQuestView() }
            .windowTitle("Star Quest · Kenney UI")
            .windowMode(.windowed)
            .minimumSize(width: 760, height: 820)
    }
}
