@_spi(AdaEngine) import AdaEngine
import Foundation
import Testing
import Yams

@testable import AdaEditor

@MainActor
@Suite("Scene selection regressions", .serialized)
struct EditorSceneSelectionRegressionTests {
    @Test("YAML payloads preserve scalar types, nested collections and JSON encoding")
    func payloadRoundTrip() throws {
        let value = EditorSceneValue.object([
            "null": .null,
            "bool": .bool(true),
            "int": .int(-42),
            "uint": .uint(.max),
            "double": .double(1.25),
            "string": .string("true"),
            "multiline": .string("first\nsecond\n"),
            "array": .array([.string("123"), .object(["empty": .array([])])]),
            "mapping": .object([:]),
        ])
        let yaml = try YAMLEncoder().encode(value)
        #expect(try YAMLDecoder().decode(EditorSceneValue.self, from: yaml) == value)
        let json = try JSONEncoder().encode(value)
        #expect(try JSONDecoder().decode(EditorSceneValue.self, from: json) == value)
    }

    @Test("A viewport click on a scene with a large terrain payload completes promptly and persists selection")
    func largePayloadSelection() throws {
        var model = EditorSceneModel.default(projectName: "Large terrain")
        let targetID = try #require(model.rootEntityID)
        let other = model.addEntity(name: "Terrain", parentID: nil)
        let otherIndex = try #require(model.entities.firstIndex { $0.id == other.id })
        model.entities[otherIndex].components["TerrainData"] = [
            "vertices": .array((0..<8_192).map { index in
                .object(["position": .array([.double(Double(index)), .double(0), .double(0)])])
            }),
        ]
        let content = try model.encodedYAML()
        let world = World()
        world.spawn("SceneView_Camera") { Camera(); Transform() }
        let target = world.spawn { Transform() }
        let viewport = EditorSceneViewportModel()
        var publishedContent: String?
        var publications = 0
        viewport.configure(
            sceneContent: content, model: model,
            onSelectionChanged: { _ in },
            onDocumentContentChanged: { publishedContent = $0; publications += 1 }
        )
        viewport.attachSceneWorld(world, loadResult: .init(
            entityCount: 1, warnings: [], entitiesByEditorID: [targetID: target.id], editorIDsByEntityID: [target.id: targetID]
        ))
        viewport.setViewportSize(Size(width: 1_280, height: 720))
        viewport.setDisplayMode(.threeD)
        viewport.setActiveTool(.select)
        viewport.perspectiveBlend = 1
        let position = try #require(viewport.project(.zero, size: viewport.viewportSize))
        let clock = ContinuousClock()
        let started = clock.now
        for phase in [MouseEvent.Phase.began, .ended] {
            #expect(viewport.handleInput(MouseEvent(
                window: RID(), button: .left, mousePosition: position, phase: phase, modifierKeys: [], time: 0
            )))
        }
        let elapsed = started.duration(to: clock.now)
        print("Large terrain viewport selection: \(elapsed)")
        #expect(elapsed < .seconds(5))
        #expect(viewport.selectedEditorID == targetID)
        #expect(publications == 1)
        let published = try #require(publishedContent)
        let decoded = try EditorSceneModel.decode(from: published)
        #expect(decoded.editor?.selectedEntity == targetID)
        #expect(decoded.entities == model.entities)
        viewport.onSelectEntity?(targetID)
        #expect(publications == 1)
    }

    @Test("Selection and foldouts retain runtime entities while authored edits reload them")
    func editorStateRetainsRuntime() throws {
        var model = EditorSceneModel.default(projectName: "Retained preview")
        let rootID = try #require(model.rootEntityID)
        let child = model.addEntity(name: "Child", parentID: rootID)
        let viewport = EditorSceneViewportModel()
        viewport.configure(
            sceneContent: try model.encodedYAML(), model: model,
            onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in }
        )
        let world = World()
        let result = EditorSceneFileLoader.load(model: model, into: world, loadsScriptableObjects: false)
        viewport.attachSceneWorld(world, loadResult: result)
        let runtimeID = try #require(result.entitiesByEditorID[child.id])
        let original = try #require(world.getEntityByID(runtimeID))
        model.selectEntity(rootID)
        model.toggleEntityExpanded(rootID)
        var selectedID: String?
        let unchanged = viewport.configure(
            sceneContent: try model.encodedYAML(), model: model,
            onSelectionChanged: { selectedID = $0?.editorID }, onDocumentContentChanged: { _ in }
        )
        #expect(unchanged == nil)
        #expect(world.getEntityByID(runtimeID) === original)
        #expect(selectedID == rootID)
        let renamed = model.renameEntity(child.id, to: "Renamed")
        #expect(renamed)
        let changed = viewport.configure(
            sceneContent: try model.encodedYAML(), model: model,
            onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in }
        )
        #expect(changed != nil)
        #expect(world.getEntityByID(runtimeID) !== original)
    }
}
