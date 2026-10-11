import AdaEngine
import Foundation
import Testing

@testable import AdaEditor

@Suite("VR project Build and Run", .serialized)
@MainActor
struct EditorVRProjectRunTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
    }

    @Test("Run compiles saved buffers into a native Play session and Stop retains authoring")
    func nativeRunAndStop() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = EditorProjectStore(storageURL: root.appendingPathComponent("recents.json"), documentsDirectoryURL: root)
        let project = try store.createProject(named: "NativePlay", at: root, template: .adaScript)
        let workspace = EditorVRWorkspace(store: store)
        try workspace.openProject(at: URL(fileURLWithPath: project.path))
        let editor = try #require(workspace.studio)
        editor.selectedRunDestination = .visionOS
        let source = try #require(editor.projectSidebar.items.first { $0.title == "Main.ada" })
        editor.openProjectItem(source)
        let text = try #require(workspace.workbench.textDocument(id: workspace.workbench.activeDocumentID))
        let updated = text.content + "\n// saved before native Run\n"
        workspace.workbench.updateTextDocument(id: text.id) { $0.content = updated; $0.isDirty = true }
        if let scene = workspace.document { workspace.workbench.open(.scene(scene)) }
        let documents = workspace.workbench.openDocuments.map(\.id)
        let scene = workspace.document?.content

        editor.runFromToolbar()
        await editor.workspaceTask?.value
        let play = try #require(workspace.playSession)
        #expect(editor.adaScriptRuntimeWindow == nil)
        #expect(editor.adaScriptRuntimeControls === play.controls)
        #expect(editor.workspaceStatus == .running("Run NativePlay"))
        #expect(try String(contentsOfFile: try #require(text.absolutePath), encoding: .utf8) == updated)
        #expect(workspace.workbench.openDocuments.map(\.id) == documents)
        #expect(workspace.document?.content == scene)

        editor.stopFromToolbar()
        #expect(workspace.playSession == nil)
        #expect(editor.adaScriptRuntimeControls == nil)
        #expect(editor.workspaceStatus == .ready)
        #expect(workspace.workbench.openDocuments.map(\.id) == documents)
        #expect(workspace.document?.content == scene)

        editor.runFromToolbar()
        await editor.workspaceTask?.value
        let restarted = try #require(workspace.playSession)
        #expect(restarted.id != play.id)
        workspace.stopPlay(id: play.id)
        #expect(workspace.playSession === restarted)
        #expect(workspace.closeProject())
        #expect(workspace.playSession == nil)
    }

    @Test("An invalid saved source reports a build failure and never opens Play")
    func invalidSourceBlocksRun() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = EditorProjectStore(storageURL: root.appendingPathComponent("recents.json"))
        let project = try store.createProject(named: "InvalidPlay", at: root, template: .adaScript)
        let workspace = EditorVRWorkspace(store: store)
        try workspace.openProject(at: URL(fileURLWithPath: project.path))
        let editor = try #require(workspace.studio)
        editor.selectedRunDestination = .visionOS
        let source = try #require(editor.projectSidebar.items.first { $0.title == "Main.ada" })
        editor.openProjectItem(source)
        let text = try #require(workspace.workbench.textDocument(id: workspace.workbench.activeDocumentID))
        workspace.workbench.updateTextDocument(id: text.id) { $0.content = "class {"; $0.isDirty = true }
        editor.buildAll()
        await editor.workspaceTask?.value
        if case let .failed(message) = editor.workspaceStatus {
            #expect(!message.isEmpty)
            #expect(editor.outputLines.contains { $0.text == message })
        } else {
            Issue.record("Expected AdaScript build failure")
        }
        #expect(workspace.playSession == nil)
    }

    @Test("visionOS project destination persists and rejects SwiftPM projects")
    func visionDestinationCompatibility() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        var project = ProjectSystem.defaultProject(buildSystem: .swiftpm)
        project.run.destination = .visionOS
        try ProjectSystem.saveProject(project, at: root)
        #expect(try ProjectSystem.loadProject(at: root).run.destination == .visionOS)
        #expect(EditorRunDestination.visionOS.adaProjectDestination == .visionOS)
        #expect(EditorViewModel.editorRunDestination(from: .visionOS) == .visionOS)
        #expect(throws: ProjectSystemError.self) {
            try ProjectSystem.validateRunCompatibility(of: project, at: root, destination: .visionOS)
        }
    }
}
