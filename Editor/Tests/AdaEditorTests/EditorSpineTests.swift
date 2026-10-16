@_spi(Internal) @testable import AdaApp
@_spi(AdaEngine) import AdaEngine
@testable import AdaEditor
@_spi(Internal) @testable import AdaRender
import AdaSpine
import Foundation
import Testing

@MainActor
@Suite(.serialized)
struct EditorSpineTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        EditorComponentRegistry.registerBuiltIns()
    }

    @Test func importsJSONAtlasAndAllPagesWithoutOverwriting() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = try fixture(in: directory.appendingPathComponent("Export"))
        let assets = directory.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        #expect(EditorSpineAssetImporter.accepts(export))
        let first = try EditorSpineAssetImporter.copy(export, to: assets)
        let second = try EditorSpineAssetImporter.copy(export, to: assets)
        #expect(first != second && first.pathExtension == "spine")
        for file in [first, second] {
            #expect(FileManager.default.fileExists(atPath: file.deletingPathExtension().appendingPathExtension("atlas").path))
            #expect(FileManager.default.fileExists(atPath: file.deletingLastPathComponent().appendingPathComponent("hero.png").path))
        }
        #expect(try Data(contentsOf: export) == Data(contentsOf: first))
        #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "skel") == .spine2D)
    }

    @Test func rejectsEscapingAtlasPageBeforeCreatingAnImport() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = try fixture(in: directory.appendingPathComponent("Export"))
        let atlas = export.deletingPathExtension().appendingPathExtension("atlas")
        try String(contentsOf: atlas, encoding: .utf8).replacingOccurrences(of: "hero.png", with: "../outside.png")
            .write(to: atlas, atomically: true, encoding: .utf8)
        try Image(width: 16, height: 16, color: .white).writePNG(to: directory.appendingPathComponent("outside.png"))
        let destination = directory.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        #expect(throws: (any Error).self) { try EditorSpineAssetImporter.copy(export, to: destination) }
        #expect(try FileManager.default.contentsOfDirectory(atPath: destination.path).isEmpty)
    }

    @Test func addSaveReopenAndLoadEditableSpineCharacter() async throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = try fixture(in: directory.appendingPathComponent("Export"))
        let assets = directory.appendingPathComponent("Assets")
        try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
        let file = try EditorSpineAssetImporter.copy(export, to: assets)
        let reference = "@res://hero/hero.spine"
        let scene = EditorSceneModel.default(projectName: "Spine")
        let sceneURL = assets.appendingPathComponent("Main.ascn")
        let document = EditorSceneDocument(id: "main", title: "Main.ascn", relativePath: "Assets/Main.ascn", absolutePath: sceneURL.path,
            content: try scene.encodedYAML(), sceneModel: scene, isDirty: true, loadSummary: .init(entityCount: scene.entities.count, warnings: []))
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(document)], activeDocumentID: document.id)
        let asset = EditorAssetDocument(id: "hero", title: file.lastPathComponent, relativePath: "Assets/hero/hero.spine", absolutePath: file.path,
            assetReference: reference, kind: .spine2D, fileExtension: "spine")
        #expect(workbench.addSpineAsset(asset, to: document.id, animation: "move", showBones: true))
        #expect(workbench.saveAllDocuments())
        let saved = try String(contentsOf: sceneURL, encoding: .utf8)
        let reopened = try EditorSceneModel.decode(from: saved)
        let authored = try #require(reopened.entities.first { $0.components[EditorBuiltInComponentType.spineSource] != nil })
        #expect(authored.components[EditorBuiltInComponentType.spineSource]?["source"] == .string(reference))
        let app = AppWorlds(main: World())
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(RenderWorldPlugin()).addPlugin(SpinePlugin())
        try await app.build()
        let result = EditorSceneFileLoader.load(content: saved, into: app.main, loadsScriptableObjects: false, sourceURL: sceneURL, resourceRootURL: assets)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let entity = try #require(result.entitiesByEditorID[authored.id].flatMap(app.main.getEntityByID))
        let animation = try #require(entity.components[SpineAnimation.self])
        #expect(entity.components[SpineDebugBones.self] != nil)
        #expect(animation.player.animationNames == ["move"])
        let before = animation.player.time
        await app.main.runScheduler(.update, deltaTime: 0.25)
        #expect(animation.player.time > before)
    }

    @Test func previewPauseAndBoneTogglePreserveTheAnimationClock() throws {
        let directory = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let export = try fixture(in: directory)
        let handle = try AssetsManager.loadSync(SpineSkeleton.self, at: export.path)
        let preview = EditorSpinePreviewModel()
        preview.skeleton = try #require(handle.asset)
        preview.animation = "move"
        let world = World()
        preview.attach(to: world)
        let entity = try #require(world.getEntities().first { $0.components[SpineAnimation.self] != nil })
        let player = try #require(entity.components[SpineAnimation.self]?.player)
        player.advance(by: 0.4)
        preview.isPlaying = false
        preview.showBones = false
        preview.update(in: world)
        #expect(entity.components[SpineAnimation.self]?.isPaused == true)
        #expect(entity.components[SpineDebugBones.self] == nil)
        #expect(entity.components[SpineAnimation.self]?.player === player)
        #expect(abs(player.time - 0.4) < 0.001)
    }

    @Test func importedSkeletonDrawsAfterAnimationAndRespondsToVisibility() async throws {
        GLTFLoaderResolver.shared.setLoader(NativeGLTFLoader())
        let engine = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let asset = try #require(AssetsManager.loadSync(ModelAsset3D.self, at: engine.appendingPathComponent("Tests/AdaAssetsTests/Fixtures/TwoBoneRibbon.glb").path).asset)
        let app = AppWorlds(main: World())
        let overlay = EditorSkeleton3DOverlay()
        let debug = DebugDraw3D()
        app.addPlugin(MainSchedulerPlugin()).addPlugin(TransformPlugin()).addPlugin(Model3DPlugin())
        app.insertResource(overlay).insertResource(debug)
        app.addPlugin(EditorSkeleton3DPlugin())
        let root = asset.instantiate(in: app.main)
        try await app.build()
        await app.main.runScheduler(.postUpdate, deltaTime: 0)
        #expect(debug.lineCount == 0)
        overlay.isEnabled = true
        await app.main.runScheduler(.postUpdate, deltaTime: 0)
        #expect(debug.lineCount > 0)
        var animation = try #require(root.components[ModelAnimation3DComponent.self])
        try animation.player.play("Bend", transitionDuration: 0)
        root.components[ModelAnimation3DComponent.self] = animation
        debug.clear()
        await app.main.runScheduler(.postUpdate, deltaTime: 0.5)
        #expect(debug.lineCount > 0)
        #expect(root.components[ModelAnimation3DComponent.self]?.player.time ?? 0 > 0)
        overlay.isEnabled = false
        debug.clear()
        await app.main.runScheduler(.postUpdate, deltaTime: 0.5)
        #expect(debug.lineCount == 0)
    }

    @Test func skeletonLinksSkipNonJointHelperNodes() throws {
        let rig = try SkeletalRig(nodes: [
            .init(parentIndex: nil, restPose: .init(), restMatrix: .identity),
            .init(parentIndex: 0, restPose: .init(), restMatrix: .identity),
            .init(parentIndex: 1, restPose: .init(), restMatrix: .identity),
            .init(parentIndex: 0, restPose: .init(), restMatrix: .identity),
        ])
        let links = EditorSkeleton3DOverlay.links(joints: [0, 2], rig: rig)
        #expect(links.count == 1)
        #expect(links.first?.0 == 0 && links.first?.1 == 2)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("editor-spine-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func fixture(in directory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("hero.json")
        try Data(Self.skeleton.utf8).write(to: url)
        try Data("hero.png\nsize: 16,16\nfilter: Linear,Linear\nbody\nbounds: 0,0,16,16\n".utf8)
            .write(to: directory.appendingPathComponent("hero.atlas"))
        try Image(width: 16, height: 16, color: .white).writePNG(to: directory.appendingPathComponent("hero.png"))
        return url
    }

    private static let skeleton = #"""
    {"skeleton":{"spine":"4.2.00"},"bones":[{"name":"root","length":12}],
    "slots":[{"name":"body","bone":"root","attachment":"body"}],
    "skins":[{"name":"default","attachments":{"body":{"body":{"width":16,"height":16}}}}],
    "animations":{"move":{"bones":{"root":{"translatex":[{"value":0},{"time":1,"value":20}]}}}}}
    """#
}
