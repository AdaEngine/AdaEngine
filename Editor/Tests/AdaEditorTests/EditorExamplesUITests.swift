@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Math
import Testing

@testable import AdaEditor

@Suite("Studio HUB examples", .serialized)
@MainActor
struct EditorExamplesUITests {
    @Test("The HUB renders catalog entries and a download action")
    func catalogInHub() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "ExamplesUITests")))
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ExamplesUI-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let model = ProjectOpeningViewModel(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        let item = EditorExampleCatalog.Item(
            id: "arena",
            kind: "sample",
            title: "Arena",
            description: "A complete game.",
            path: "Samples/Arena",
            preview: "Assets/Previews/arena.png",
            archive: "Arena.zip",
            tags: ["AdaScript", "2D", "Desktop"]
        )
        model.examples.items = [item]
        model.examples.selected = item
        model.selectSection(.samples)
        let container = UIContainerView(rootView: ProjectOpeningView(autoOpenLastProject: false, viewModel: model).theme(.adaEditor))
        container.frame = Rect(x: 0, y: 0, width: 1_024, height: 700)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let entry = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Launcher.Example.arena"))
        let button = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Launcher.DownloadExample"))
        #expect(entry.absoluteFrame.height > 0)
        #expect(button.absoluteFrame.height > 0)
        #expect(button.absoluteFrame.maxX <= 1_024)
        #expect(button.absoluteFrame.maxY <= 700)
    }

    @Test("A downloaded project opens through the production project store")
    func downloadedProjectOpens() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ExamplesOpen-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let source = root.appendingPathComponent("catalog/Samples/Arena")
        try FileManager.default.createDirectory(at: source.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Arena", buildSystem: .adaScript), at: source)
        try "// Game systems\n".write(to: source.appendingPathComponent("Sources/Game.ada"), atomically: true, encoding: .utf8)
        let catalog = """
        {"schemaVersion":1,"items":[{
          "id":"arena","kind":"sample","title":"Arena","description":"A game","path":"Samples/Arena",
          "preview":"Assets/Previews/arena.png","archive":"Arena.zip","tags":["AdaScript","2D","Desktop"]
        }]}
        """
        try catalog.write(to: root.appendingPathComponent("catalog/catalog.json"), atomically: true, encoding: .utf8)
        let examples = EditorExamplesViewModel(service: EditorExampleService(localRoot: root.appendingPathComponent("catalog")))
        let launcher = ProjectOpeningViewModel(store: EditorProjectStore(storageURL: root.appendingPathComponent("recents.json")))
        await examples.refresh()
        await examples.download(to: root) { launcher.openProject(at: $0) }
        #expect(launcher.operationErrorMessage == nil)
        #expect(launcher.projectToOpenInEditor?.name == "Arena")
        #expect(launcher.recentProjects.count == 1)
        #expect(examples.message == "Downloaded Arena.")
    }
}
