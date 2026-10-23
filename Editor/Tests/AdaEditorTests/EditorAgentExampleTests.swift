@_spi(Internal) @testable import AdaRender
@_spi(AdaEngine) import AdaEngine
import AdaScriptCompilerCore
@_spi(Internal) import AdaUI
import Foundation
import MCP
import Testing

@testable import AdaEditor
@testable import AdaScripting

/// The bundled side-scroller example and the AdaScript snippets in the agent skills and gameplay recipes are real code,
/// so they are compiled and run here instead of being trusted as prose.
@MainActor
@Suite("Agent example projects", .serialized)
struct EditorAgentExampleTests {
    private static let editorRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    private func example() throws -> EditorAgentKnowledge.Example {
        EditorComponentRegistry.registerBuiltIns()
        return try #require(EditorAgentKnowledge.examples.first { $0.id == EditorAgentBundledExamples.sideScrollerID })
    }

    private func sources(_ files: [String: String], prefixes: [String]) -> [AdaScriptSource] {
        let selected = files.filter { entry in entry.key.hasSuffix(".ada") && prefixes.contains { entry.key.hasPrefix($0) } }
        return selected.sorted { $0.key < $1.key }.map { AdaScriptSource(path: $0.key, source: $0.value) }
    }

    @Test("The side-scroller example is split into one file per responsibility")
    func layout() throws {
        let files = try example().files
        for path in [
            ".ada/project.json", "Assets/Scenes/Main.ascn", "Assets/UI/Hud.ui", "README.md", "Sources/Config.ada", "Sources/Rules.ada",
            "Sources/Components/Player.ada", "Sources/Components/Obstacle.ada", "Sources/Components/GameState.ada",
            "Sources/Systems/InputSystem.ada", "Sources/Systems/FlightSystem.ada", "Sources/Systems/ObstacleSystem.ada",
            "Sources/Systems/CollisionSystem.ada", "Sources/Systems/ScoreSystem.ada", "Sources/Systems/AudioSystem.ada",
            "Sources/UI/Hud.ada", "Tests/RoundTests.ada", "Tests/RulesTests.ada",
        ] {
            #expect(files[path] != nil, "\(path)")
        }
        for (path, text) in files where path.hasPrefix("Sources/") {
            #expect(text.split(separator: "\n").count <= 80, "\(path) is too long for one responsibility")
        }
        let main = files["Sources/Main.ada"]
        #expect(main == nil)
    }

    @Test("The example compiles without diagnostics and every @test passes")
    func compilesAndPassesItsTests() throws {
        let files = try example().files
        let production = try AdaScriptPlugin(sources: sources(files, prefixes: ["Sources/"]), name: "SideRunnerGame")
        #expect(production.diagnostics.isEmpty, Comment(rawValue: production.diagnostics.joined(separator: "\n")))

        let plugin = try AdaScriptPlugin(sources: sources(files, prefixes: ["Sources/", "Tests/"]), name: "SideRunner", includeTests: true)
        let results = plugin.runTests()
        #expect(results.count >= 10)
        #expect(results.allSatisfy { $0.outcome == .passed }, Comment(rawValue: AdaScriptTestReport.summary(results)))
        #expect(plugin.diagnostics.isEmpty, Comment(rawValue: plugin.diagnostics.joined(separator: "\n")))
    }

    @Test("The scene, project and HUD agree with the scripts")
    func sceneMatchesScripts() throws {
        let files = try example().files
        let project = try ProjectSystem.loadProject(from: Data(try #require(files[".ada/project.json"]).utf8))
        #expect(project.inputActions.map(\.name) == ["Flap", "Restart"])
        let gameplay = (files.filter { $0.key.hasPrefix("Sources/") }.values).joined(separator: "\n")
        for action in project.inputActions { #expect(gameplay.contains("\"\(action.name)\""), "\(action.name)") }

        let scene = try EditorSceneModel.decode(from: try #require(files[SceneDocumentFormat.defaultScenePath]))
        let ids = Set(scene.entities.map(\.id))
        #expect(ids.isSuperset(of: ["camera", "sun", "player", "game", "sound-flap", "sound-score", "sound-crash"]))
        #expect(scene.entities.filter { $0.components["runner.obstacle"] != nil }.count == 4)
        for entity in scene.entities { if let parent = entity.parent { #expect(ids.contains(parent), "\(entity.id)") } }
        for key in scene.entities.flatMap({ $0.components.keys }).filter({ $0.hasPrefix("runner.") }) {
            #expect(gameplay.contains("\"\(key)\""), "\(key) is not declared by a script")
        }

        let hud = try #require(scene.entities.first { $0.id == "game" })
        let uiPayload = try #require(hud.components[EditorBuiltInComponentType.uiComponent])
        let decoded = try EditorComponentRegistry.decode(typeName: EditorBuiltInComponentType.uiComponent, payload: uiPayload)
        let ui = try #require(decoded as? UIComponent)
        let uiFile = try #require(files["Assets/UI/Hud.ui"])
        for (input, binding) in try #require(ui.source?.scriptBindings) {
            #expect(uiFile.contains("\"\(input)\""), "\(input)")
            #expect(files["Sources/UI/Hud.ada"]?.contains("var \(binding.field) ") == true, "\(binding.field)")
        }

        for entity in scene.entities {
            guard let audio = entity.components[EditorBuiltInComponentType.audioSource]?["source"]?.stringValue else { continue }
            let name = audio.replacingOccurrences(of: "@res://Audio/", with: "").replacingOccurrences(of: ".wav", with: "")
            #expect(files["Generators/\(name).sound.txt"] != nil, "no generator for \(audio)")
        }
    }

    @Test("Studio prepares the example as an AdaScript project")
    func studioAcceptsTheProject() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        let files = try example().files
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("SideRunnerExample-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        for (path, text) in files {
            let url = root.appendingPathComponent(path)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try text.write(to: url, atomically: true, encoding: .utf8)
        }
        let project = try ProjectSystem.loadProject(at: root)
        let artifact = try EditorAdaScriptProjectBuilder().prepare(project: project, at: root)
        #expect(artifact.report.sourceCount == files.keys.filter { $0.hasPrefix("Sources/") && $0.hasSuffix(".ada") }.count)
        #expect(artifact.sceneModel != nil)

        let runtime = UIComponentRuntime(resourceRoot: artifact.assetsDirectory)
        let hud = try runtime.resources.load(runtime.resources.resolve("@res://UI/Hud.ui"))
        #expect(Set(hud.inputs.map(\.name)) == ["score", "status", "hint"])
        _ = try MobileEditorSceneValidation.validate(artifact, at: root)
    }

    @Test("The asset generator sources of the example run")
    func generatorsRun() throws {
        let files = try example().files
        let sounds = files.filter { $0.key.hasSuffix(".sound.txt") }
        #expect(sounds.count == 3)
        for (path, source) in sounds {
            let report = AudioAnalyzer.analyze(try AdaScriptSoundGenerator.generate(source: source))
            #expect(report.clippedSamples == 0 && report.leadingSilence < 0.01 && report.duration < 1.2, "\(path)")
        }
        let model = try AdaScriptModelGenerator.generate(source: try #require(files["Generators/bird.model.txt"]))
        #expect(model.nodes.count > 3)
    }

    @Test("editor.examples.list finds the example by genre words")
    func listFindsExample() async throws {
        for query in ["3D game", "side scroller", "flappy", "runner", "AudioSource"] {
            let result = try EditorAgentKnowledge.query(name: "editor.examples.list", arguments: ["query": .string(query)])
            let ids = (result["examples"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
            #expect(ids.contains(EditorAgentBundledExamples.sideScrollerID), "\(query)")
        }
        let unrelated = try EditorAgentKnowledge.query(name: "editor.examples.list", arguments: ["query": "voxel terrain"])
        #expect((unrelated["examples"] as? [Any])?.isEmpty == true)
        let all = try EditorAgentKnowledge.query(name: "editor.examples.list", arguments: [:])
        #expect((all["examples"] as? [Any])?.count ?? 0 >= 4)
    }

    private var skillsRoot: URL { Self.editorRoot.appendingPathComponent("Sources/AdaEditor/Assets/AgentSkills") }

    private func fencedBlocks(_ text: String) -> [String] {
        text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "```").enumerated().filter { $0.offset % 2 == 1 }.map { block in
            block.element.split(separator: "\n", omittingEmptySubsequences: false).dropFirst().joined(separator: "\n")
        }
    }

    @Test("Every recipe block in the gameplay recipes article compiles and its tests pass")
    func recipeBlocksRun() throws {
        let article = try String(contentsOf: Self.editorRoot.appendingPathComponent("Documentation/AdaScriptGameplayRecipes.md"), encoding: .utf8)
        let recipes = fencedBlocks(article).filter { $0.hasPrefix("// recipe") }
        #expect(recipes.count >= 6)
        var tests = 0
        for (index, source) in recipes.enumerated() {
            let plugin = try AdaScriptPlugin(sources: [AdaScriptSource(path: "Recipe\(index).ada", source: source)], name: "Recipe\(index)", includeTests: true)
            let results = plugin.runTests()
            tests += results.count
            #expect(results.allSatisfy { $0.outcome == .passed }, Comment(rawValue: "recipe \(index): " + AdaScriptTestReport.summary(results)))
            #expect(plugin.diagnostics.isEmpty, Comment(rawValue: "recipe \(index): " + plugin.diagnostics.joined(separator: "\n")))
        }
        #expect(tests >= 5)
    }

    @Test("The offline documentation carries the recipes and points at the example")
    func recipesAreInOfflineDocs() throws {
        let result = try EditorAgentKnowledge.query(name: "editor.docs.search", arguments: ["query": "gameplay recipes"])
        let ids = (result["articles"] as? [[String: Any]])?.compactMap { $0["id"] as? String } ?? []
        #expect(ids.contains("AdaScriptGameplayRecipes"))
        let article = try EditorAgentKnowledge.query(name: "editor.docs.read", arguments: ["id": "AdaScriptGameplayRecipes"])
        let content = try #require(article["content"] as? String)
        #expect(content.contains(EditorAgentBundledExamples.sideScrollerID))
        #expect(content.contains("AudioSource"))
    }

    @Test("Skill code blocks compile and skills only name skills that exist")
    func skillsAreConsistent() throws {
        let sound = try String(contentsOf: skillsRoot.appendingPathComponent("ada-sound-design/SKILL.md"), encoding: .utf8)
        let systems = fencedBlocks(sound).filter { $0.contains("@system") }
        #expect(systems.count == 1)
        for source in systems {
            let plugin = try AdaScriptPlugin(sources: [AdaScriptSource(path: "Sound.ada", source: source)], name: "SkillSound")
            #expect(plugin.diagnostics.isEmpty, Comment(rawValue: plugin.diagnostics.joined(separator: "\n")))
        }

        let installed = Set(try FileManager.default.contentsOfDirectory(atPath: skillsRoot.path))
        for name in installed {
            let text = try String(contentsOf: skillsRoot.appendingPathComponent("\(name)/SKILL.md"), encoding: .utf8)
            let mentioned = text.matches(of: /`(ada-[a-z0-9-]+)`/).map { String($0.1) }
            for id in mentioned { #expect(installed.contains(id) || id == "ada-chat-ui", "\(name) mentions missing skill \(id)") }
        }

        let studio = try String(contentsOf: skillsRoot.appendingPathComponent("ada-autonomous-studio/SKILL.md"), encoding: .utf8)
        for phrase in ["Start card", "M2, art and sound", "3-6 sounds", "blocker:", "manual:", "at most about 10 read-only calls", "Do not plan \"primitives\" or \"silence\""] {
            #expect(studio.contains(phrase), "\(phrase)")
        }
        let coding = try String(contentsOf: skillsRoot.appendingPathComponent("ada-coding/SKILL.md"), encoding: .utf8)
        for phrase in ["One file, one responsibility", "Config", "AGENTS.md", "side-scroller-3d"] { #expect(coding.contains(phrase), "\(phrase)") }
    }
}
