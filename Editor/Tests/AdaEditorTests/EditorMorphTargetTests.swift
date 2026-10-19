import Foundation
import Math
import Testing

@_spi(Internal) @testable import AdaApp
@testable import AdaEditor
@_spi(AdaEngine) @testable import AdaEngine
@_spi(Internal) @testable import AdaRender
@_spi(Internal) import AdaUI
import AdaUtils

@MainActor
@Suite(.serialized)
struct EditorMorphTargetTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
        GLTFLoaderResolver.shared.setLoader(NativeGLTFLoader())
        EditorComponentRegistry.registerBuiltIns()
    }

    /// A one-quad glTF with two named morph targets ("smile" resting at 0.25, "blink" at 0) written into `directory`.
    private func writeModel(in directory: URL, targetNames: [String]? = ["smile", "blink"]) throws -> URL {
        var bytes = Data()
        var views: [[String: Any]] = []
        func add(_ data: Data) {
            views.append(["buffer": 0, "byteOffset": bytes.count, "byteLength": data.count])
            bytes.append(data)
            while bytes.count % 4 != 0 { bytes.append(0) }
        }
        func floats(_ values: [Float]) -> Data {
            var data = Data()
            for value in values { withUnsafeBytes(of: value.bitPattern.littleEndian) { data.append(contentsOf: $0) } }
            return data
        }
        add(floats([-0.5, 0, 0, 0.5, 0, 0, -0.5, 1, 0, 0.5, 1, 0]))
        var indices = Data()
        for index in [0, 1, 2, 2, 1, 3] as [UInt16] { withUnsafeBytes(of: index.littleEndian) { indices.append(contentsOf: $0) } }
        add(indices)
        add(floats([0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0]))
        add(floats([0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0, 0, 0.3, 0]))
        func accessor(_ view: Int, _ type: String, _ count: Int, _ component: Int = 5126) -> [String: Any] {
            ["bufferView": view, "componentType": component, "count": count, "type": type]
        }
        var positions = accessor(0, "VEC3", 4)
        positions["min"] = [-0.5, 0, 0]
        positions["max"] = [0.5, 1, 0]
        var mesh: [String: Any] = [
            "weights": [0.25, 0],
            "primitives": [["attributes": ["POSITION": 0], "indices": 1, "targets": [["POSITION": 2], ["POSITION": 3]]]],
        ]
        if let targetNames { mesh["extras"] = ["targetNames": targetNames] }
        let document: [String: Any] = [
            "asset": ["version": "2.0"],
            "buffers": [["byteLength": bytes.count, "uri": "data:application/octet-stream;base64," + bytes.base64EncodedString()]],
            "bufferViews": views,
            "accessors": [positions, accessor(1, "SCALAR", 6, 5123), accessor(2, "VEC3", 4), accessor(3, "VEC3", 4)],
            "meshes": [mesh],
            "nodes": [["mesh": 0]],
            "scenes": [["nodes": [0]]],
            "scene": 0,
        ]
        let url = directory.appendingPathComponent("Face.gltf")
        try JSONSerialization.data(withJSONObject: document).write(to: url)
        return url
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("MorphTargets-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func loadAsset(_ url: URL) throws -> ModelAsset3D {
        try #require(AssetsManager.loadSync(ModelAsset3D.self, at: url.path).asset)
    }

    @Test("The model lists named targets with the file's default weights and drops authored names the model lacks")
    func listsTargets() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let asset = try loadAsset(writeModel(in: directory))
        let model = EditorMorphTargetsModel()
        model.configure(asset: asset, authored: ["smile": 0.7, "unknown": 1])
        #expect(model.targets == [.init(name: "smile", defaultWeight: 0.25), .init(name: "blink", defaultWeight: 0)])
        #expect(model.unnamedTargetCount == 0)
        #expect(model.weights == ["smile": 0.7], "A name the model does not have is dropped.")
        #expect(model.weight(of: model.targets[0]) == 0.7 && model.weight(of: model.targets[1]) == 0)

        let unnamed = EditorMorphTargetsModel()
        unnamed.configure(asset: try loadAsset(writeModel(in: directory, targetNames: nil)), authored: [:])
        #expect(unnamed.targets.isEmpty && unnamed.unnamedTargetCount == 2, "Targets without names cannot be addressed from a scene.")
    }

    @Test("Weights clamp, and returning a target to its default removes the override")
    func editsWeights() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorMorphTargetsModel()
        model.configure(asset: try loadAsset(writeModel(in: directory)), authored: [:])
        let smile = model.targets[0], blink = model.targets[1]
        #expect(!model.hasAuthoredWeights)
        model.setWeight(5, for: blink)
        model.setWeight(.nan, for: smile)
        #expect(model.weights == ["blink": 1], "Weights clamp to the slider range and non-finite values are ignored.")
        model.setWeight(0.25, for: smile)
        #expect(model.weights == ["blink": 1], "A weight equal to the file's default is not an override.")
        model.setWeight(0.5, for: smile)
        model.setWeight(0, for: blink)
        #expect(model.weights == ["smile": 0.5])
        model.reset()
        #expect(model.weights.isEmpty && !model.hasAuthoredWeights)
    }

    @Test("The payload round trips and ignores non-numbers")
    func payloadRoundTrip() {
        let weights: [String: Float] = ["smile": 0.5, "blink": 1]
        #expect(EditorMorphWeightsPayload.decode(EditorMorphWeightsPayload.encode(weights)) == weights)
        #expect(EditorMorphWeightsPayload.decode(nil).isEmpty && EditorMorphWeightsPayload.decode(.string("x")).isEmpty)
        #expect(EditorMorphWeightsPayload.decode(.object(["a": .string("no"), "b": .int(1), "c": .double(.nan)])) == ["b": 1])
    }

    /// A scene with one Model 3D entity that points at `Face.gltf` in `directory`, open in a workbench.
    private func makeWorkbench(in directory: URL) throws -> (workbench: EditorWorkbenchViewModel, target: EditorSkeletalAnimationTarget, entityID: String, sceneURL: URL) {
        _ = try writeModel(in: directory)
        let sceneURL = directory.appendingPathComponent("Main.ascn")
        var scene = EditorSceneModel.default(projectName: "Morph")
        let entity = scene.addEntity(template: .importedModel3D, parentID: scene.rootEntityID)
        let index = try #require(scene.entities.firstIndex { $0.id == entity.id })
        scene.entities[index].components[EditorBuiltInComponentType.model3DSource] = [
            "source": .string("@res://Face.gltf"), "animation": .string(""), "autoplay": .bool(false), "repeats": .bool(true),
        ]
        let content = try scene.encodedYAML()
        try content.write(to: sceneURL, atomically: true, encoding: .utf8)
        let document = EditorSceneDocument(
            id: "Scene", title: "Main", relativePath: "Main.ascn", absolutePath: sceneURL.path,
            content: content, lastSavedContent: content, sceneModel: scene, isDirty: false,
            loadSummary: .init(entityCount: 0, warnings: [])
        )
        let workbench = EditorWorkbenchViewModel(openDocuments: [.scene(document)], activeDocumentID: "Scene")
        let target = EditorSkeletalAnimationTarget(documentID: "Scene", entityID: entity.id, source: .init(source: "@res://Face.gltf"), sceneURL: sceneURL)
        return (workbench, target, entity.id, sceneURL)
    }

    @Test("Applying saves structured scene data and supports undo, redo and clearing")
    func sceneTransaction() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (workbench, target, entityID, sceneURL) = try makeWorkbench(in: directory)

        #expect(workbench.setMorphWeights(["smile": 0.8, "blink": 1], target: target))
        #expect(workbench.saveAllDocuments())
        let reopened = try EditorSceneModel.decode(from: String(contentsOf: sceneURL, encoding: .utf8))
        let saved = try #require(reopened.entities.first { $0.id == entityID }?.components[EditorBuiltInComponentType.model3DSource])
        #expect(EditorMorphWeightsPayload.decode(saved["morphWeights"]) == ["smile": 0.8, "blink": 1])
        let decoded = try #require(EditorComponentRegistry.decode(typeName: EditorBuiltInComponentType.model3DSource, payload: saved) as? Model3DSource)
        #expect(decoded.morphWeights == ["smile": 0.8, "blink": 1])

        #expect(workbench.performDocumentHistory(redo: false))
        let undone = try #require(workbench.activeSceneDocument?.sceneModel?.entities.first { $0.id == entityID })
        #expect(undone.components[EditorBuiltInComponentType.model3DSource]?["morphWeights"] == nil)
        #expect(workbench.performDocumentHistory(redo: true))
        let redone = try #require(workbench.activeSceneDocument?.sceneModel?.entities.first { $0.id == entityID })
        #expect(EditorMorphWeightsPayload.decode(redone.components[EditorBuiltInComponentType.model3DSource]?["morphWeights"]) == ["smile": 0.8, "blink": 1])

        // Clearing removes the key rather than leaving an empty map.
        #expect(workbench.setMorphWeights([:], target: target))
        let cleared = try #require(workbench.activeSceneDocument?.sceneModel?.entities.first { $0.id == entityID })
        #expect(cleared.components[EditorBuiltInComponentType.model3DSource]?["morphWeights"] == nil)
        let missing = EditorSkeletalAnimationTarget(documentID: "Scene", entityID: "missing", source: .init(source: "x"), sceneURL: sceneURL)
        #expect(!workbench.setMorphWeights(["smile": 1], target: missing), "A target that no longer exists changes nothing.")
    }

    /// Needs the scene file loader, which the Editor tests of this package cannot run in every environment (the existing
    /// `EditorAnimationGraphTests` scene round trip ends the test process the same way where it fails).
    @Test("A saved scene opens in the runtime with the authored weights")
    func loaderAppliesAuthoredWeights() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let (workbench, target, _, sceneURL) = try makeWorkbench(in: directory)
        #expect(workbench.setMorphWeights(["smile": 0.8, "blink": 1], target: target))
        #expect(workbench.saveAllDocuments())
        let reopened = try EditorSceneModel.decode(from: String(contentsOf: sceneURL, encoding: .utf8))
        let world = World()
        let result = EditorSceneFileLoader.load(content: try reopened.encodedYAML(), into: world, sourceURL: sceneURL, resourceRootURL: directory)
        #expect(result.warnings.isEmpty, Comment(rawValue: result.warnings.joined(separator: "\n")))
        let morphed = try #require(world.getEntities().first { $0.components[MorphWeights3DComponent.self] != nil })
        #expect(morphed.components[MorphWeights3DComponent.self]?.weights == [0.8, 1])
    }

    @Test("The preview applies the weights to the model it shows, including defaults put back")
    func previewShowsWeights() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let asset = try loadAsset(writeModel(in: directory))
        let world = World()
        _ = asset.instantiate(in: world)
        let preview = EditorModelAssetPreviewModel()
        preview.asset = asset
        preview.bind(to: world)
        func weights() throws -> [Float]? {
            try #require(world.getEntities().first { $0.components[MorphWeights3DComponent.self] != nil }).components[MorphWeights3DComponent.self]?.weights
        }
        #expect(try weights() == [0.25, 0], "The file's defaults show before anything is authored.")
        preview.morphWeights = ["smile": 0.9, "blink": 0.4]
        #expect(try weights() == [0.9, 0.4])
        preview.morphWeights = ["smile": 0.25, "blink": 0]
        #expect(try weights() == [0.25, 0], "Giving every target its default weight undoes the preview.")
    }

    @Test("The weight list draws one named slider per target")
    func listShowsSliders() async throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let model = EditorMorphTargetsModel()
        model.configure(asset: try loadAsset(writeModel(in: directory)), authored: ["smile": 0.5])
        let container = UIContainerView(rootView: EditorMorphWeightList(model: model))
        container.frame = Rect(x: 0, y: 0, width: 480, height: 160)
        container.bounds.size = container.frame.size
        for _ in 0..<3 {
            try await Task.sleep(for: .milliseconds(1))
            container.update(1 / 60)
            container.layoutIfNeeded()
        }
        for name in ["smile", "blink"] {
            _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Morph.Name.\(name)"))
            _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.Morph.Slider.\(name)"))
        }
    }
}
