import AdaEngine
import Foundation
import Testing

@testable import AdaEditor

@Suite("VR editor workspace", .serialized)
@MainActor
struct EditorVRWorkspaceTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
    }

    @Test("Spatial movement after reentering immersion commits one document/undo step on release")
    func spatialTransactionSaveUndo() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = EditorProjectStore(storageURL: directory.appendingPathComponent("recents.json"), documentsDirectoryURL: directory)
        let workspace = EditorVRWorkspace(store: store)
        try workspace.createStarter(at: directory)
        let original = try #require(workspace.document)
        let model = try #require(original.sceneModel)
        let box = try #require(model.entities.first { $0.name == "Box" })
        let world = World()
        workspace.attachWorld(world)
        workspace.finishImmersion()
        workspace.attachWorld(World())
        workspace.select(box.id)
        let baseline = try #require(workspace.document)
        workspace.viewport.beginSpatialTransform(editorID: box.id)
        for x: Float in [0.2, 0.4, 0.8] {
            workspace.viewport.updateSpatialTransform(Transform(position: [x, 1.2, 1.5]), editorID: box.id)
        }
        #expect(workspace.document?.content == baseline.content)
        workspace.viewport.endSpatialTransform()
        let edited = try #require(workspace.document)
        #expect(edited.isDirty)
        #expect(workspace.workbench.sceneUndoHistory[edited.id]?.count == 1)
        let payload = try #require(edited.sceneModel?.entities.first { $0.id == box.id }?.components[EditorBuiltInComponentType.transform])
        let transform = try #require(try EditorComponentPayloadDecoder.decode(Transform.self, payload: payload) as? Transform)
        #expect((transform.position - Vector3(0.8, 1.2, 1.5)).length < 0.0001)
        workspace.save()
        #expect(workspace.document?.isDirty == false)
        let onDisk = try String(contentsOfFile: try #require(edited.absolutePath), encoding: .utf8)
        #expect(onDisk == workspace.document?.content)
        workspace.undo()
        #expect(
            workspace.document?.sceneModel?.entities.first { $0.id == box.id }?.components[EditorBuiltInComponentType.transform]
                == baseline.sceneModel?.entities.first { $0.id == box.id }?.components[EditorBuiltInComponentType.transform])
        workspace.redo()
        #expect(workspace.document?.content == edited.content)
    }

    @Test("Production spatial input selects a nested entity, updates Inspector and saves one undo step")
    func spatialInputToDocument() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: directory.appendingPathComponent("recent.json")))
        try workspace.createStarter(at: directory)
        let box = try #require(workspace.document?.sceneModel?.entities.first { $0.name == "Box" })
        workspace.modifyDocument { model in
            let parent = model.addEntity(template: .empty, parentID: nil)
            model.entities[model.entities.firstIndex { $0.id == parent.id } ?? 0].components[EditorBuiltInComponentType.transform] = [
                "position": .array([.double(2), .double(0), .double(0)]),
                "rotation": .array([.double(0), .double(0), .double(0), .double(1)]),
                "scale": .array([.double(1), .double(1), .double(1)]),
            ]
            model.reparentEntity(box.id, to: parent.id)
        }
        workspace.save()
        let world = World()
        workspace.attachWorld(world)
        world.insertResource(SpatialSelection())
        world.insertResource(SpatialInput())
        world.addSystem(SpatialInteractionSystem.self, on: .update)
        let entity = try #require(workspace.viewport.runtimeEntity(for: box.id))
        #expect(entity.components[SpatialGrabbable.self] != nil)
        let parent = try #require(entity.parent?.components[Transform.self])
        let start = (parent.matrix * (try #require(entity.components[Transform.self])).matrix).origin
        world.insertResource(SpatialInput(grips: [SpatialGrip(interactor: .leftHand, pose: Transform3D(translation: start))]))
        await world.runScheduler(.update)
        workspace.frame(world)
        #expect(workspace.inspector.selectedEntity?.editorID == box.id)
        #expect(workspace.isManipulating)
        let baseline = try #require(workspace.document)
        let count = workspace.workbench.sceneUndoHistory[baseline.id]?.count ?? 0
        world.insertResource(SpatialInput(grips: [SpatialGrip(interactor: .leftHand, pose: Transform3D(translation: start + Vector3(0.5, 0, 0)))]))
        await world.runScheduler(.update)
        workspace.frame(world)
        #expect(workspace.document?.content == baseline.content)
        let field = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.transform)?.fields.first { $0.key == "position" })
        #expect(workspace.inspector.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: field, axisIndex: 0).wrappedValue == "0")
        world.insertResource(SpatialInput())
        await world.runScheduler(.update)
        workspace.frame(world)
        #expect(!workspace.isManipulating)
        #expect(workspace.workbench.sceneUndoHistory[baseline.id]?.count == count + 1)
        workspace.save()
        #expect(workspace.document?.isDirty == false)
        workspace.undo()
        #expect(
            workspace.document?.sceneModel?.entities.first { $0.id == box.id }?.components[EditorBuiltInComponentType.transform]
                == baseline.sceneModel?.entities.first { $0.id == box.id }?.components[EditorBuiltInComponentType.transform])
    }

    @Test("Cancelling a spatial edit restores the original transform without a document edit")
    func cancelledSpatialEdit() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let workspace = EditorVRWorkspace(store: EditorProjectStore(storageURL: directory.appendingPathComponent("recent.json")))
        try workspace.createStarter(at: directory)
        let box = try #require(workspace.document?.sceneModel?.entities.first { $0.name == "Box" })
        let world = World()
        workspace.attachWorld(world)
        workspace.select(box.id)
        let baseline = try #require(workspace.document)
        workspace.viewport.beginSpatialTransform(editorID: box.id)
        workspace.viewport.updateSpatialTransform(Transform(position: [7, 0, 3]), editorID: box.id)
        workspace.viewport.endSpatialTransform(cancelled: true)
        #expect(workspace.document?.content == baseline.content)
        #expect(workspace.workbench.sceneUndoHistory[baseline.id]?.isEmpty != false)
    }
}
