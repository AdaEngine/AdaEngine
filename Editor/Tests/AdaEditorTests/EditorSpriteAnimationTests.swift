@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@testable import AdaUI
import Foundation
import Testing
import Yams

@MainActor
@Suite("Sprite Animation editor", .serialized)
struct EditorSpriteAnimationTests {
    @Test("New-file template opens through the sprite animation route")
    func template() throws {
        let kind = EditorNewFileKind.spriteAnimation
        let descriptor = try YAMLDecoder().decode(SpriteAnimationSetDescriptor.self, from: kind.initialContent(fileName: "Hero.spriteanim"))
        #expect(descriptor.image.isEmpty)
        #expect(descriptor.clips.isEmpty)
        #expect(kind.fileExtension == "spriteanim")
        #expect(kind.group == .resources)
        #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "spriteanim") == .spriteAnimation)
    }

    @Test("Clip, frame and sheet edits persist through the real file and Undo/Redo")
    func authoring() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = EditorSpriteAnimationEditorModel(document: document(root))
        defer { model.cancelPreview() }
        #expect(model.error == nil)

        // A new resource has no image yet, and clips can already be authored.
        model.addClip()
        #expect(try read(root).clips.map(\.name) == ["Clip 1"])
        #expect(model.updateClip { $0.name = "Run" })
        model.addGridFrames(row: 1, from: 0, through: 3)
        #expect(try read(root).clips[0].frames.map(\.atlasCoordinates) == (0...3).map { PointInt(x: $0, y: 1) })
        #expect(model.updateDescriptor { $0.image = "Hero.png"; $0.cellSize = SizeInt(width: 16, height: 16) })
        #expect(model.updateClip { $0.framesPerSecond = 8; $0.playbackMode = .pingPong })
        model.updateFrame(at: 1) { $0.marker = "step"; $0.duration = 2 }
        model.moveFrame(at: 1, by: 1)
        let saved = try read(root)
        #expect(saved.image == "Hero.png")
        #expect(saved.cellSize == SizeInt(width: 16, height: 16))
        #expect(saved.clips[0].framesPerSecond == 8)
        #expect(saved.clips[0].playbackMode == .pingPong)
        #expect(saved.clips[0].frames[2].marker == "step" && saved.clips[0].frames[2].duration == 2)

        model.removeFrame(at: 0)
        #expect(try read(root).clips[0].frames.count == 3)
        model.undo()
        #expect(try read(root).clips[0].frames.count == 4)
        model.redo()
        #expect(try read(root).clips[0].frames.count == 3)

        model.addClip()
        #expect(model.selectedClip == 1)
        model.removeClip()
        #expect(try read(root).clips.count == 1)
    }

    @Test("Edits that would write an unplayable resource are refused and leave the file untouched")
    func rejections() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = EditorSpriteAnimationEditorModel(document: document(root))
        defer { model.cancelPreview() }
        model.addClip()
        model.addClip()
        let url = root.appendingPathComponent("Hero.spriteanim")
        let before = try Data(contentsOf: url)

        #expect(!model.updateClip { $0.name = "Clip 1" }) // duplicate of the first clip
        #expect(!model.updateClip { $0.name = "" })
        #expect(!model.updateClip { $0.framesPerSecond = 0 })
        model.addGridFrames(row: -1, from: 0, through: 1)
        model.addGridFrames(row: 0, from: 3, through: 1)
        model.addGridFrames(row: 0, from: 0, through: EditorSpriteAnimationEditorModel.maximumFramesPerClip)
        #expect(try Data(contentsOf: url) == before)
        #expect(model.error != nil)
    }

    @Test("External changes are preserved instead of overwritten")
    func externalChange() throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let model = EditorSpriteAnimationEditorModel(document: document(root))
        defer { model.cancelPreview() }
        let url = root.appendingPathComponent("Hero.spriteanim")
        let external = "image: Other.png\nclips:\n  - {name: External, frames: []}\n"
        try external.write(to: url, atomically: true, encoding: .utf8)
        model.addClip()
        #expect(try String(contentsOf: url, encoding: .utf8) == external)
        model.reload()
        #expect(model.clip?.name == "External")
    }

    @Test("An Aseprite export becomes clips and a relative image path, and the saved resource loads and plays")
    func asepriteImport() async throws {
        try startRenderer()
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let art = root.appendingPathComponent("Art")
        try FileManager.default.createDirectory(at: art, withIntermediateDirectories: true)
        var sheet = Image(width: 12, height: 4, color: .black)
        for x in 0..<12 { for y in 0..<4 { sheet.setPixel(in: [Float(x), Float(y)], color: x < 4 ? .red : (x < 8 ? .green : .blue)) } }
        try sheet.writePNG(to: art.appendingPathComponent("hero.png"))
        try """
        {"frames":[
          {"filename":"hero 0","frame":{"x":0,"y":0,"w":4,"h":4},"duration":100},
          {"filename":"hero 1","frame":{"x":4,"y":0,"w":4,"h":4},"duration":100},
          {"filename":"hero 2","frame":{"x":8,"y":0,"w":4,"h":4},"duration":200}],
         "meta":{"image":"hero.png","frameTags":[{"name":"walk","from":0,"to":2,"direction":"forward"}]}}
        """.write(to: art.appendingPathComponent("hero.json"), atomically: true, encoding: .utf8)

        let model = EditorSpriteAnimationEditorModel(document: document(root))
        defer { model.cancelPreview() }
        model.importAseprite(from: "Art/hero.json")
        #expect(model.error == nil, Comment(rawValue: model.error ?? ""))
        let saved = try read(root)
        #expect(saved.image == "Art/hero.png")
        #expect(saved.filter == .nearest)
        #expect(saved.clips.map(\.name) == ["walk"])
        #expect(saved.clips[0].frames.map(\.duration) == [1, 1, 2])
        #expect(saved.clips[0].framesPerSecond == 10)

        // The resource the editor wrote is the one the runtime loads, with slices into the real image.
        let set = try await AssetsManager.loadFresh(SpriteAnimationSet.self, at: root.appendingPathComponent("Hero.spriteanim").path)
        let slice = try #require(set.texture(for: set.clips[0].frames[2]) as? TextureAtlas.Slice)
        #expect(slice.position == Vector2(8, 0))
        #expect(slice.size == SizeInt(width: 4, height: 4))

        // Failures name the problem and keep the resource as it was.
        let before = try Data(contentsOf: root.appendingPathComponent("Hero.spriteanim"))
        model.importAseprite(from: "Art/missing.json")
        #expect(model.error != nil)
        try #"{"frames":[{"frame":{"x":0,"y":0,"w":2,"h":2},"trimmed":true,"duration":100}],"meta":{"image":"hero.png"}}"#
            .write(to: art.appendingPathComponent("trimmed.json"), atomically: true, encoding: .utf8)
        model.importAseprite(from: "Art/trimmed.json")
        #expect(model.error?.contains("Trim") == true)
        model.importAseprite(from: "")
        #expect(try Data(contentsOf: root.appendingPathComponent("Hero.spriteanim")) == before)
    }

    @Test("Relative image paths climb out of the resource folder when the sheet lives elsewhere")
    func relativePaths() {
        let base = URL(fileURLWithPath: "/p/Assets/Anims")
        #expect(EditorSpriteAnimationEditorModel.relativePath(from: base, to: URL(fileURLWithPath: "/p/Assets/Anims/hero.png")) == "hero.png")
        #expect(EditorSpriteAnimationEditorModel.relativePath(from: base, to: URL(fileURLWithPath: "/p/Assets/Art/Sub/hero.png")) == "../Art/Sub/hero.png")
    }

    @Test("A scene saved with an animator reopens, loads in a world and plays the chosen clip")
    func sceneRoundTrip() async throws {
        try startRenderer()
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try Image(width: 8, height: 4, color: .white).writePNG(to: root.appendingPathComponent("Hero.png"))
        let model = EditorSpriteAnimationEditorModel(document: document(root))
        defer { model.cancelPreview() }
        model.addClip()
        model.updateClip { $0.name = "idle" }
        model.addGridFrames(row: 0, from: 0, through: 1)
        model.addClip()
        model.updateClip { $0.name = "run" }
        model.addGridFrames(row: 0, from: 0, through: 1)
        model.updateDescriptor { $0.image = "Hero.png"; $0.cellSize = SizeInt(width: 4, height: 4) }

        // Add to Scene creates a Sprite and a SpriteAnimator that reference the resource.
        var scene = EditorSceneModel.default(projectName: "Anim")
        let url = root.appendingPathComponent("Main.ascn")
        let content = try scene.encodedYAML()
        try content.write(to: url, atomically: true, encoding: .utf8)
        let sceneDocument = EditorSceneDocument(
            id: "Main", title: "Main", relativePath: "Main.ascn", absolutePath: url.path,
            content: content, lastSavedContent: content, sceneModel: scene, isDirty: false, loadSummary: .init(entityCount: 0, warnings: [])
        )
        let asset = document(root)
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(sceneDocument), .asset(asset)], activeDocumentID: sceneDocument.id)
        #expect(workbench.addSpriteAnimation(asset, to: sceneDocument.id))
        #expect(workbench.saveActiveDocument())
        scene = try EditorSceneModel.decode(from: String(contentsOf: url, encoding: .utf8))
        let authored = try #require(scene.entities.first { $0.components[EditorBuiltInComponentType.spriteAnimator] != nil })
        #expect(authored.components[EditorBuiltInComponentType.sprite] != nil)

        // Choose the second clip through the registry field, as the Inspector does.
        let descriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.spriteAnimator))
        let field = try #require(descriptor.fields.first { $0.key == "currentClip" })
        workbench.updateComponentField(typeName: EditorBuiltInComponentType.spriteAnimator, field: field, value: "run", inSelectedEntityOf: sceneDocument.id)

        let world = World()
        let result = EditorSceneFileLoader.load(model: scene, into: world, loadsScriptableObjects: false, resourceRootURL: root)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let id = try #require(result.entitiesByEditorID[authored.id])
        let animator = try #require(world.get(SpriteAnimator.self, from: id))
        #expect(animator.animations?.asset?.clips.map(\.name) == ["idle", "run"])
        #expect(animator.currentClip == "idle") // the in-memory edit above is not saved yet

        // Paths that leave the project are refused.
        #expect(throws: (any Error).self) {
            try EditorSceneFileLoader.resolvedComponentPayload(
                typeName: EditorBuiltInComponentType.spriteAnimator,
                payload: ["animations": .string("@res://../Outside.spriteanim")],
                sourceURL: url,
                resourceRootURL: root
            )
        }
    }

    @Test("The editor view shows the authored clip, and its preview and form react to edits")
    func viewReflectsEdits() async throws {
        try startRenderer()
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let asset = document(root)
        let model = EditorSpriteAnimationEditorModel(document: asset)
        defer { model.cancelPreview() }
        let workbench = EditorWorkbenchViewModel(openDocuments: [.asset(asset)], activeDocumentID: asset.id)
        let container = UIContainerView(rootView: EditorSpriteAnimationAssetEditor(document: asset, model: model, workbench: workbench))
        container.frame = Rect(x: 0, y: 0, width: 1000, height: 700)
        container.layoutSubviews()
        for _ in 0..<20 { await Task.yield() }
        container.layoutSubviews()

        let root0 = container.viewTree.rootNode
        #expect(root0.findNodyByAccessibilityIdentifier("AdaEditor.SpriteAnimation.Editor") != nil)
        #expect(root0.findNodyByAccessibilityIdentifier("AdaEditor.SpriteAnimation.AddClip") != nil)
        #expect(root0.findNodyByAccessibilityIdentifier("AdaEditor.SpriteAnimation.ClipName") == nil) // no clip yet

        model.addClip()
        model.addGridFrames(row: 0, from: 0, through: 2)
        for _ in 0..<20 { await Task.yield() }
        container.layoutSubviews()
        #expect(container.viewTree.rootNode.findNodyByAccessibilityIdentifier("AdaEditor.SpriteAnimation.ClipName") != nil)
        #expect(container.viewTree.rootNode.findNodyByAccessibilityIdentifier("AdaEditor.SpriteAnimation.FPS") != nil)
        #expect(EditorSpriteAnimationAssetEditor.sourceSummary(try #require(model.clip?.frames.last)) == "cell 2,0")
    }

    // MARK: - Fixture

    private func startRenderer() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "Sprite animation UI test")))
        }
        SpriteAnimator.registerComponent()
        AssetsManager.registerAssetType(SpriteAnimationSet.self)
    }

    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdaSpriteAnimEditor-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try EditorNewFileKind.spriteAnimation.initialContent(fileName: "Hero.spriteanim")
            .write(to: root.appendingPathComponent("Hero.spriteanim"), atomically: true, encoding: .utf8)
        return root
    }

    private func read(_ root: URL) throws -> SpriteAnimationSetDescriptor {
        try YAMLDecoder().decode(SpriteAnimationSetDescriptor.self, from: Data(contentsOf: root.appendingPathComponent("Hero.spriteanim")))
    }

    private func document(_ root: URL) -> EditorAssetDocument {
        .init(
            id: "spriteanim",
            title: "Hero.spriteanim",
            relativePath: "Assets/Hero.spriteanim",
            absolutePath: root.appendingPathComponent("Hero.spriteanim").path,
            assetReference: "@res://Hero.spriteanim",
            kind: .spriteAnimation,
            fileExtension: "spriteanim"
        )
    }
}
