@_spi(Internal) @testable import AdaApp
@_spi(AdaEngine) @testable import AdaEngine
@_spi(Internal) @testable import AdaRender
import Foundation
import MCP
import Testing

@testable import AdaEditor

/// MagicaVoxel (.vox) models in the editor: import, drop, resolve, scene save/load, preview and tool boundaries.
@MainActor
@Suite("Voxel models in the editor", .serialized)
struct EditorVoxelModelTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        EditorComponentRegistry.registerBuiltIns()
    }

    // MARK: - Import

    @Test("Import and file drop copy a vox file next to earlier imports without overwriting", arguments: [false, true])
    func importsVoxFiles(drop: Bool) async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture("robot", in: root.appendingPathComponent("Export"))
        let project = try EditorProjectStore(storageURL: root.appendingPathComponent("projects.json"), distribution: .standalone)
            .createProject(named: "Voxel Import", at: root)
        let editor = EditorViewModel(project: project)
        if drop {
            editor.projectSidebar.select(try #require(editor.projectSidebar.items.first { $0.relativePath == "Assets" }))
            #expect(editor.importDroppedFiles(from: [source]))
            await editor.sourceControl.refreshTask?.value
            #expect(editor.importDroppedFiles(from: [source]))
        } else {
            editor.importAssets(from: [source])
            await editor.sourceControl.refreshTask?.value
            editor.importAssets(from: [source])
        }
        await editor.sourceControl.refreshTask?.value

        let files = editor.projectSidebar.items.filter { $0.title.hasSuffix(".vox") }
        #expect(files.count == 2)
        #expect(Set(files.map(\.title)).count == 2, "A second import must not overwrite the first")
        #expect(EditorViewModel.modelAssets(from: files).count == 2)
        for item in files {
            guard case let .asset(document) = EditorViewModel.document(for: item) else {
                Issue.record("A vox file must open in the 3D preview")
                continue
            }
            #expect(document.kind == .model3D)
            #expect(EditorProjectFileAppearance.resolve(for: item) == .mesh)
            let path = try #require(document.absolutePath)
            #expect(try Data(contentsOf: URL(fileURLWithPath: path)) == Data(contentsOf: source))
        }
    }

    @Test("A vox file is classified as a 3D model asset")
    func classifiesVoxAsModel() {
        #expect(EditorModelResource.extensions.contains("vox"))
        #expect(EditorModelResource.gltfExtensions == ["glb", "gltf"])
        #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "vox") == .model3D)
        #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "VOX") == .model3D)
    }

    // MARK: - Resolve

    @Test("Voxel references resolve inside project assets and escapes are rejected")
    func resolvesReferences() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let assets = root.appendingPathComponent("Assets")
        let model = try fixture("castle", in: assets)

        let resolved = try EditorModelResource.resolve("@res://castle.vox", sourceURL: nil, resourceRootURL: assets)
        #expect(resolved == model.resolvingSymlinksInPath().standardizedFileURL)

        let outside = try fixture("castle", in: root.appendingPathComponent("Outside"))
        #expect(throws: (any Error).self) {
            try EditorModelResource.resolve("@res://../Outside/\(outside.lastPathComponent)", sourceURL: nil, resourceRootURL: assets)
        }
        #expect(throws: (any Error).self) {
            try EditorModelResource.resolve("@res://missing.vox", sourceURL: nil, resourceRootURL: assets)
        }
        // Other extensions are still not models.
        try Data("x".utf8).write(to: assets.appendingPathComponent("notes.txt"))
        #expect(throws: (any Error).self) {
            try EditorModelResource.resolve("@res://notes.txt", sourceURL: nil, resourceRootURL: assets)
        }
    }

    // MARK: - Scenes

    @Test("Add a voxel model, save and reopen, then load it in edit and Play", arguments: [false, true])
    func savedVoxelModelLoads(play: Bool) async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let assets = root.appendingPathComponent("Assets")
        let source = try fixture("robot", in: assets)
        let sceneURL = assets.appendingPathComponent("Main.ascn")
        let initial = EditorSceneModel.default(projectName: "Voxels")
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(try sceneDocument(initial, at: sceneURL))], activeDocumentID: "scene:Main")
        #expect(workbench.addModelAsset(assetDocument(source), to: "scene:Main", autoplay: true))
        #expect(workbench.saveAllDocuments())

        let content = try String(contentsOf: sceneURL, encoding: .utf8)
        let reopened = try EditorSceneModel.decode(from: content)
        let authored = try #require(reopened.entities.first { $0.components[EditorBuiltInComponentType.model3DSource] != nil })
        #expect(authored.name == "robot")
        #expect(authored.components[EditorBuiltInComponentType.model3DSource]?["source"] == .string("@res://robot.vox"))

        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(Model3DPlugin())
        try await app.build()
        let result = EditorSceneFileLoader.load(content: content, into: app.main, loadsScriptableObjects: play, sourceURL: sceneURL, resourceRootURL: assets)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let ownerID = try #require(result.entitiesByEditorID[authored.id])
        let owner = try #require(app.main.getEntityByID(ownerID))
        let generated = try #require(owner.children.first)

        // The imported scene keeps its named parts and meshes.
        var pending = generated.children
        var names: [String] = []
        var meshCount = 0
        while let entity = pending.popLast() {
            names.append(entity.name)
            meshCount += entity.components[Mesh3DComponent.self] == nil ? 0 : 1
            pending.append(contentsOf: entity.children)
        }
        #expect(Set(["body", "head", "arm"]).isSubset(of: Set(names)))
        #expect(meshCount == 3)

        // Autoplay was authored, so the voxel clock runs.
        let playback = try #require(generated.components[VoxelAnimationPlayback3DComponent.self])
        #expect(playback.isPlaying)
        let before = playback.time
        await app.main.runScheduler(.postUpdate, deltaTime: 0.1)
        #expect(try #require(generated.components[VoxelAnimationPlayback3DComponent.self]).time > before)
    }

    @Test("A model added without autoplay keeps its voxel animation paused")
    func pausedByDefault() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let assets = root.appendingPathComponent("Assets")
        let source = try fixture("robot", in: assets)
        let sceneURL = assets.appendingPathComponent("Main.ascn")
        let initial = EditorSceneModel.default(projectName: "Voxels")
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(try sceneDocument(initial, at: sceneURL))], activeDocumentID: "scene:Main")
        #expect(workbench.addModelAsset(assetDocument(source), to: "scene:Main"))
        #expect(workbench.saveAllDocuments())

        let content = try String(contentsOf: sceneURL, encoding: .utf8)
        let authored = try #require(try EditorSceneModel.decode(from: content).entities.first { $0.components[EditorBuiltInComponentType.model3DSource] != nil })
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(Model3DPlugin())
        try await app.build()
        let result = EditorSceneFileLoader.load(content: content, into: app.main, loadsScriptableObjects: false, sourceURL: sceneURL, resourceRootURL: assets)
        let ownerID = try #require(result.entitiesByEditorID[authored.id])
        let owner = try #require(app.main.getEntityByID(ownerID))
        let generated = try #require(owner.children.first)

        #expect(generated.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == false)
    }

    // MARK: - Import settings

    @Test("The Model 3D inspector offers voxel settings with importer defaults")
    func inspectorFields() throws {
        let descriptor = EditorComponentRegistry.model3DSourceDescriptor
        let fields = Dictionary(uniqueKeysWithValues: descriptor.fields.map { ($0.key, $0) })

        #expect(fields["voxelSize"]?.kind == .float)
        #expect(fields["voxelSize"]?.defaultValue == .double(0.1))
        #expect(fields["voxelSize"]?.minimumValue == 0.001)
        #expect(fields["voxelMergeStatic"]?.kind == .bool)
        #expect(fields["voxelFramesPerSecond"]?.defaultValue == .double(30))
        #expect(fields["voxelFramesPerSecond"]?.minimumValue == 1)

        // A plain model keeps the source untouched.
        let plain = try #require(try descriptor.decode(descriptor.makeDefaultPayload()) as? Model3DSource)
        #expect(plain.voxel == nil)
        var payload = descriptor.makeDefaultPayload()
        payload["source"] = .string("@res://castle.vox")
        payload["voxelSize"] = .double(0.1)
        #expect(try #require(try descriptor.decode(payload) as? Model3DSource).voxel == nil, "Defaults must not create settings")

        payload["voxelSize"] = .double(0.05)
        payload["voxelMergeStatic"] = .bool(true)
        payload["voxelFramesPerSecond"] = .double(12)
        let configured = try #require(try descriptor.decode(payload) as? Model3DSource)
        #expect(configured.voxel == VoxelImportSettings(voxelSize: 0.05, mergeStatic: true, framesPerSecond: 12))
        #expect(configured.assetPath == "@res://castle.vox#voxelSize=0.05&mergeStatic=1&fps=12.0")
    }

    @Test("Voxel settings survive save and reopen and scale the loaded model", arguments: [false, true])
    func settingsRoundTripThroughScenes(play: Bool) async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let assets = root.appendingPathComponent("Assets")
        let source = try fixture("castle", in: assets)
        let sceneURL = assets.appendingPathComponent("Main.ascn")
        let initial = EditorSceneModel.default(projectName: "Voxels")
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(try sceneDocument(initial, at: sceneURL))], activeDocumentID: "scene:Main")
        #expect(workbench.addModelAsset(assetDocument(source), to: "scene:Main"))
        #expect(workbench.saveAllDocuments())

        var scene = try EditorSceneModel.decode(from: String(contentsOf: sceneURL, encoding: .utf8))
        let index = try #require(scene.entities.firstIndex { $0.components[EditorBuiltInComponentType.model3DSource] != nil })
        scene.entities[index].components[EditorBuiltInComponentType.model3DSource]?["voxelSize"] = .double(0.2)
        scene.entities[index].components[EditorBuiltInComponentType.model3DSource]?["voxelMergeStatic"] = .bool(true)
        let content = try scene.encodedYAML()

        let reopened = try EditorSceneModel.decode(from: content)
        let payload = try #require(reopened.entities[index].components[EditorBuiltInComponentType.model3DSource])
        #expect(payload["voxelSize"]?.doubleValue == 0.2)
        #expect(payload["voxelMergeStatic"]?.boolValue == true)

        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(Model3DPlugin())
        try await app.build()
        let result = EditorSceneFileLoader.load(content: content, into: app.main, loadsScriptableObjects: play, sourceURL: sceneURL, resourceRootURL: assets)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let ownerID = try #require(result.entitiesByEditorID[reopened.entities[index].id])
        let owner = try #require(app.main.getEntityByID(ownerID))
        let reference = try #require(owner.components[Model3DSource.self])
        #expect(reference.voxel == VoxelImportSettings(voxelSize: 0.2, mergeStatic: true))

        // The 16-voxel castle is 1.6 units wide at 0.1 and 3.2 at 0.2.
        var pending = try #require(owner.children.first).children
        var width: Float = 0
        while let entity = pending.popLast() {
            if let mesh = entity.components[Mesh3DComponent.self]?.mesh {
                width = max(width, mesh.bounds.max.x - mesh.bounds.min.x)
            }
            pending.append(contentsOf: entity.children)
        }
        #expect(abs(width - 3.2) < 0.01)
    }

    // MARK: - Preview

    @Test("The model preview shows voxel details and its Play button drives the voxel clock")
    func previewControlsVoxelPlayback() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture("robot", in: root)

        let preview = EditorModelAssetPreviewModel()
        preview.asset = try #require(AssetsManager.loadSync(ModelAsset3D.self, at: source.path).asset)
        #expect(preview.hasVoxelAnimation)
        #expect(preview.voxelTimelineDescription == "11 frames at 30 fps")
        #expect(preview.animationNames == ["Rest pose"])
        #expect(max(preview.normalizedBounds.halfExtents.x, max(preview.normalizedBounds.halfExtents.y, preview.normalizedBounds.halfExtents.z)) == 1.5)

        let world = World()
        let owner = world.spawn("Preview")
        let rootEntity = try Model3DSource(source: source.path, autoplay: true).instantiate(try #require(preview.asset), in: world, under: owner)
        preview.bind(to: world)
        #expect(rootEntity.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == true)

        preview.playsAnimation = false
        #expect(rootEntity.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == false)
        preview.playsAnimation = true
        #expect(rootEntity.components[VoxelAnimationPlayback3DComponent.self]?.isPlaying == true)
    }

    @Test("A static voxel model has no animation to play")
    func staticModelHasNoTimeline() throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try fixture("castle", in: root)

        let preview = EditorModelAssetPreviewModel()
        preview.asset = try #require(AssetsManager.loadSync(ModelAsset3D.self, at: source.path).asset)
        #expect(!preview.hasVoxelAnimation)
        #expect(preview.voxelTimelineDescription == nil)
        #expect(preview.normalizedBounds.halfExtents.x > 0)
    }

    // MARK: - Tool boundaries

    @Test("glTF agent tools refuse vox files instead of failing while parsing JSON")
    func agentToolsAreGLTFOnly() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("VoxAgent-\(UUID())")
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root.appendingPathComponent("Assets/Models"), withIntermediateDirectories: true)
        try ProjectSystem.saveProject(ProjectSystem.defaultProject(projectName: "Vox Tools", buildSystem: .adaScript), at: root)
        _ = try fixture("robot", in: root.appendingPathComponent("Assets/Models"))

        let result = await EditorMobileAgentToolService(projectURL: root).handle(
            name: "editor.model.validate",
            arguments: ["path": "Assets/Models/robot.vox"]
        )
        #expect(!result.ok)
        #expect(result.payload.contains("Expected a .glb or .gltf model"))
    }

    // MARK: - Helpers

    private func engineRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    }

    /// Copies an engine fixture into `directory` through the editor's own importer.
    private func fixture(_ name: String, in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return try EditorModelAssetImporter.copy(engineRoot().appendingPathComponent("Tests/AdaAssetsTests/Fixtures/vox/\(name).vox"), to: directory)
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("editor-voxel-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func assetDocument(_ url: URL) -> EditorAssetDocument {
        .init(
            id: "asset:\(url.lastPathComponent)",
            title: url.lastPathComponent,
            relativePath: "Assets/\(url.lastPathComponent)",
            absolutePath: url.path,
            assetReference: "@res://\(url.lastPathComponent)",
            kind: .model3D,
            fileExtension: url.pathExtension
        )
    }

    private func sceneDocument(_ scene: EditorSceneModel, at url: URL) throws -> EditorSceneDocument {
        .init(
            id: "scene:Main",
            title: "Main.ascn",
            relativePath: "Assets/Main.ascn",
            absolutePath: url.path,
            content: try scene.encodedYAML(),
            sceneModel: scene,
            isDirty: true,
            loadSummary: .init(entityCount: scene.entities.count, warnings: [])
        )
    }
}
