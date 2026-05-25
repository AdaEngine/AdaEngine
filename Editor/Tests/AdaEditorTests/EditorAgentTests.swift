@testable import AdaEditor
import Foundation
import Testing

@Suite("Editor agent")
struct EditorAgentTests {
    @Test("project agent config decodes defaults and explicit target")
    func projectAgentConfigDecoding() throws {
        let data = Data("""
        {
          "schemaVersion": 1,
          "ai": {
            "agent": {
              "enabled": true,
              "target": {
                "command": "/usr/bin/agent",
                "arguments": ["--stdio"],
                "environment": {"A": "B"},
                "cwd": "Tools"
              },
              "permissionMode": "deny",
              "skillsDirectories": [".skills"]
            }
          }
        }
        """.utf8)

        let project = try ProjectSystem.loadProject(from: data)

        #expect(project.ai.agent.enabled)
        #expect(project.ai.agent.target.command == "/usr/bin/agent")
        #expect(project.ai.agent.target.arguments == ["--stdio"])
        #expect(project.ai.agent.target.environment == ["A": "B"])
        #expect(project.ai.agent.target.cwd == "Tools")
        #expect(project.ai.agent.permissionMode == .deny)
        #expect(project.ai.agent.skillsDirectories == [".skills"])
    }

    @Test("path token parsing supports escaped whitespace")
    func pathTokens() throws {
        let token = try #require(EditorAgentPathTokens.tokenBeforeCursor(in: "look at @Sources/My\\ File.swift"))

        #expect(token.rawToken == "@Sources/My\\ File.swift")
        #expect(token.path == "Sources/My File.swift")
        #expect(EditorAgentPathTokens.escapedTokenValue("Assets/My Scene.ascn") == "Assets/My\\ Scene.ascn")
        #expect(EditorAgentPathTokens.attachmentPaths(in: "a @Sources/main.swift\nb @Assets/My\\ Scene.ascn") == ["Sources/main.swift", "Assets/My Scene.ascn"])
    }

    @Test("attachment context describes project file without inlining content")
    func attachmentContext() throws {
        let rootURL = try makeAgentTemporaryDirectory(named: "AttachmentContext")
        defer { removeAgentTemporaryDirectory(rootURL) }
        let fileURL = rootURL.appendingPathComponent("Sources/main.swift")
        try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "print(1)".write(to: fileURL, atomically: true, encoding: .utf8)

        let attachment = EditorAgentAttachmentContext.attachment(forFileAt: fileURL, projectURL: rootURL)
        let block = EditorAgentAttachmentContext.fileReferenceBlock(attachment: attachment)

        #expect(attachment.relativePath == "Sources/main.swift")
        #expect(block.contains("[Attached file: Sources/main.swift]"))
        #expect(block.contains("Content not inlined"))
    }

    @Test("project file search ranks exact and prefix matches")
    func projectFileSearch() throws {
        let rootURL = try makeAgentTemporaryDirectory(named: "FileSearch")
        defer { removeAgentTemporaryDirectory(rootURL) }
        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("Sources/Game"), withIntermediateDirectories: true)
        try "".write(to: rootURL.appendingPathComponent("Sources/Game/Main.swift"), atomically: true, encoding: .utf8)
        try "".write(to: rootURL.appendingPathComponent("Sources/Game/Gameplay.swift"), atomically: true, encoding: .utf8)

        let results = EditorAgentProjectFileSearch.search(projectURL: rootURL, query: "Game", limit: 4)

        #expect(results.contains { $0.path == "Sources/Game" && $0.isDirectory })
        #expect(results.contains { $0.path == "Sources/Game/Gameplay.swift" })
    }

    @Test("skill discovery reads SKILL frontmatter")
    func skillDiscovery() throws {
        let rootURL = try makeAgentTemporaryDirectory(named: "Skills")
        defer { removeAgentTemporaryDirectory(rootURL) }
        let skillURL = rootURL.appendingPathComponent(".skills/refactor/SKILL.md")
        try FileManager.default.createDirectory(at: skillURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try """
        ---
        id: refactor
        name: Refactor
        description: Improve structure
        allowed_tools: files.read, files.write
        ---
        Use careful refactors.
        """.write(to: skillURL, atomically: true, encoding: .utf8)

        let skills = EditorAgentSkillStore.discoverSkills(projectURL: rootURL, directories: [".skills"])

        #expect(skills.map(\.id) == ["refactor"])
        #expect(skills.first?.name == "Refactor")
        #expect(skills.first?.allowedTools == ["files.read", "files.write"])
    }

    @Test("session store persists index and active session")
    func sessionStore() async throws {
        let rootURL = try makeAgentTemporaryDirectory(named: "SessionStore")
        defer { removeAgentTemporaryDirectory(rootURL) }
        let store = EditorAgentSessionStore(projectURL: rootURL)

        let session = try await store.createSession(title: "Agent")
        var edited = session
        edited.events.append(EditorAgentEvent(kind: .runStatus, title: "Ready"))
        try await store.saveSession(edited, makeActive: true)

        #expect(try await store.activeSessionID() == session.id)
        #expect(try await store.listSessions().map(\.id) == [session.id])
        #expect(try await store.loadSession(id: session.id).events.first?.title == "Ready")
    }

    @Test("scene context snapshots selected entity")
    func sceneContextSnapshotsSelectedEntity() throws {
        var model = EditorSceneModel.default(projectName: "AgentScene")
        let entity = model.addEntity(name: "Player")
        let content = try model.encodedYAML()
        let document = EditorSceneDocument(
            id: "scene:Assets/Scenes/Main.ascn",
            title: "Main.ascn",
            relativePath: "Assets/Scenes/Main.ascn",
            absolutePath: nil,
            content: content,
            sceneModel: model,
            errorMessage: nil,
            isDirty: false,
            statusMessage: nil,
            loadSummary: EditorSceneFileLoader.summary(from: content)
        )

        let context = try #require(EditorAgentSceneContext(document: document))

        #expect(context.selectedEntityID == entity.id)
        #expect(context.selectedEntityName == "Player")
        #expect(context.sceneRelativePath == "Assets/Scenes/Main.ascn")
        #expect(context.componentNames == ["Transform"])
        #expect(context.entityYAML.contains("name: Player"))
    }

    @Test("prompt context includes selected scene entity")
    func promptContextIncludesSelectedSceneEntity() throws {
        let request = EditorAgentRunRequest(
            project: ProjectSystem.defaultProject(projectName: "Prompt"),
            projectURL: URL(fileURLWithPath: "/tmp/Prompt", isDirectory: true),
            session: EditorAgentSession(),
            mode: .build,
            prompt: "Move it to the left",
            attachments: [],
            sceneContext: EditorAgentSceneContext(
                sceneTitle: "Main.ascn",
                sceneRelativePath: "Assets/Scenes/Main.ascn",
                selectedEntityID: "player",
                selectedEntityName: "Player",
                parentID: "root",
                componentNames: ["Transform", "Sprite"],
                entityYAML: "entity:\n  id: player\n  name: Player"
            ),
            skills: []
        )

        let prompt = EditorAgentPromptContext.text(for: request)

        #expect(prompt.contains("[Scene Context]"))
        #expect(prompt.contains("Scene path: Assets/Scenes/Main.ascn"))
        #expect(prompt.contains("Selected entity: Player (player)"))
        #expect(prompt.contains("Components: Transform, Sprite"))
        #expect(prompt.contains("Move it to the left"))
    }

    @Test("view model sends prompt with token attachments through service")
    @MainActor
    func viewModelSendUsesFakeService() async throws {
        let rootURL = try makeAgentTemporaryDirectory(named: "ViewModel")
        defer { removeAgentTemporaryDirectory(rootURL) }
        try FileManager.default.createDirectory(at: rootURL.appendingPathComponent("Sources"), withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: rootURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "print(1)".write(to: rootURL.appendingPathComponent("Sources/main.swift"), atomically: true, encoding: .utf8)
        try writeProjectMetadata(
            AdaProject(
                schemaVersion: 1,
                ai: AdaProjectAI(agent: AdaProjectAgent(enabled: true, target: AdaProjectAgentTarget(command: "/bin/echo")))
            ),
            to: rootURL
        )

        let service = FakeEditorAgentService()
        let viewModel = EditorAgentViewModel(
            project: EditorProjectReference(name: "ViewModel", path: rootURL.path, lastOpenedAt: Date()),
            service: service
        )
        await viewModel.loadSessions()
        viewModel.prompt = "Please inspect @Sources/main.swift"
        viewModel.setSceneContext(EditorAgentSceneContext(
            sceneTitle: "Main.ascn",
            sceneRelativePath: "Assets/Scenes/Main.ascn",
            selectedEntityID: "root",
            selectedEntityName: "Root",
            parentID: nil,
            componentNames: ["Transform"],
            entityYAML: "entity:\n  id: root\n  name: Root"
        ))

        await viewModel.sendPromptAsync()

        let request = try #require(await service.recordedRequest())
        #expect(request.attachments.map(\.relativePath) == ["Sources/main.swift"])
        #expect(request.sceneContext?.selectedEntityID == "root")
        #expect(viewModel.activeSession?.events.contains { $0.message?.role == .assistant } == true)
        #expect(viewModel.activeSession?.upstreamSessionID == "fake-upstream")
    }

    @Test("editor view model keeps agent scene context in sync")
    @MainActor
    func editorViewModelSyncsAgentSceneContext() throws {
        var model = EditorSceneModel.default(projectName: "Sync")
        let rootID = try #require(model.entities.first?.id)
        let player = model.addEntity(name: "Player")
        model.selectEntity(rootID)
        let content = try model.encodedYAML()
        let sceneDocument = EditorSceneDocument(
            id: "scene:Assets/Scenes/Main.ascn",
            title: "Main.ascn",
            relativePath: "Assets/Scenes/Main.ascn",
            absolutePath: nil,
            content: content,
            sceneModel: model,
            errorMessage: nil,
            isDirty: false,
            statusMessage: nil,
            loadSummary: EditorSceneFileLoader.summary(from: content)
        )
        let textDocument = EditorTextDocument(
            id: "text:Sources/main.swift",
            title: "main.swift",
            relativePath: "Sources/main.swift",
            language: .swift,
            content: "",
            errorMessage: nil
        )
        let workbench = EditorWorkbenchViewModel(
            openDocuments: [.scene(sceneDocument), .text(textDocument)],
            activeDocumentID: sceneDocument.id
        )
        let agent = EditorAgentViewModel(project: nil)
        let viewModel = EditorViewModel(workbench: workbench, agent: agent)

        #expect(viewModel.agent.sceneContext?.selectedEntityID == rootID)

        viewModel.workbench.selectSceneEntity(documentID: sceneDocument.id, entityID: player.id)

        #expect(viewModel.agent.sceneContext?.selectedEntityID == player.id)

        viewModel.workbench.selectDocument(id: textDocument.id)

        #expect(viewModel.agent.sceneContext == nil)
    }
}

private actor FakeEditorAgentService: EditorAgentServicing {
    var lastRequest: EditorAgentRunRequest?

    func recordedRequest() -> EditorAgentRunRequest? {
        lastRequest
    }

    func send(
        _ request: EditorAgentRunRequest,
        onEvent: @escaping @Sendable (EditorAgentEvent) async -> Void,
        onProjectFileChanged: @escaping @Sendable (String) async -> Void
    ) async throws -> EditorAgentRunResult {
        lastRequest = request
        await onEvent(EditorAgentEvent(
            kind: .message,
            message: EditorAgentMessage(role: .assistant, segments: [.init(kind: .text, text: "done")])
        ))
        await onProjectFileChanged("Sources/main.swift")
        return EditorAgentRunResult(upstreamSessionID: "fake-upstream", assistantText: "done", stopReason: "end_turn")
    }

    func cancel(sessionID _: String) async {}
    func shutdown() async {}
}

private func makeAgentTemporaryDirectory(named name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("AdaEditorAgentTests", isDirectory: true)
        .appendingPathComponent("\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeAgentTemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}

private func writeProjectMetadata(_ project: AdaProject, to rootURL: URL) throws {
    let metadataDirectory = rootURL.appendingPathComponent(ProjectSystem.metadataDirectoryName, isDirectory: true)
    try FileManager.default.createDirectory(at: metadataDirectory, withIntermediateDirectories: true)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    try encoder.encode(project).write(to: ProjectSystem.metadataURL(forProjectAt: rootURL), options: [.atomic])
}
