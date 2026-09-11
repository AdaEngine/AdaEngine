import AdaEngine
import FoldGame

@main
struct FoldApp: App {
    var body: some AppScene {
        WindowGroup { FoldGameView() }
            .windowTitle("Fold · Foldable Preview")
            .windowMode(.windowed)
            .minimumSize(width: 1024, height: 700)
    }
}
