@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Testing

private enum EditorReflectionMode: String, CaseIterable, EditorEnumReflectable, Codable, Sendable {
    case idle
    case active
}

@Component
private struct EditorReflectedComponent: Codable, Sendable {
    var color: Color
    var offset: Vector2
    var mode: EditorReflectionMode

    init(color: Color = .white, offset: Vector2 = .zero, mode: EditorReflectionMode = .idle) {
        self.color = color
        self.offset = offset
        self.mode = mode
    }
}

@Suite("Editor scene editing")
struct EditorSceneEditingTests {
    @Test("component registry exposes built-in editable descriptors")
    func componentRegistryBuiltIns() throws {
        let transform = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.transform))
        let sprite = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.sprite))

        #expect(transform.displayName == "Transform")
        #expect(transform.fields.map(\.key) == ["position", "rotation", "scale"])
        #expect(sprite.requiredComponentTypeNames == [EditorBuiltInComponentType.visibility])

        let decoded = try EditorComponentRegistry.decode(
            typeName: EditorBuiltInComponentType.transform,
            payload: transform.makeDefaultPayload()
        )
        #expect(decoded is Transform)
    }

    @Test("component registry adapts reflected component descriptors")
    func componentRegistryReflectsGeneratedDescriptors() throws {
        EditorComponentReflectionRegistry.register(EditorReflectedComponent.editorComponentDescriptor)

        let descriptor = try #require(EditorComponentRegistry.descriptor(named: String(reflecting: EditorReflectedComponent.self)))

        #expect(descriptor.displayName == "EditorReflectedComponent")
        #expect(descriptor.fields.map(\.key) == ["color", "offset", "mode"])
        #expect(descriptor.fields.first { $0.key == "color" }?.kind == .color)
        #expect(descriptor.fields.first { $0.key == "offset" }?.kind == .vector2)
        #expect(descriptor.fields.first { $0.key == "mode" }?.kind == .enumeration(["idle", "active"]))
    }

    @Test("enumeration field edits normalize invalid values")
    func enumerationFieldEditsNormalizeInvalidValues() throws {
        var payload = EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.visibility)
        let descriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.visibility))
        let field = try #require(descriptor.fields.first { $0.key == "value" })

        field.write("not-a-case", to: &payload)

        #expect(payload["value"] == .string("visible"))
    }

    @Test("scene model adds entities and required editable components")
    func sceneModelAddsEntityAndComponents() throws {
        var model = EditorSceneModel.default(projectName: "Editing")

        let entity = model.addEntity()
        model.addComponent(typeName: EditorBuiltInComponentType.sprite, to: entity.id)

        let editedEntity = try #require(model.entities.first { $0.id == entity.id })
        #expect(editedEntity.parent == "root")
        #expect(editedEntity.components[EditorBuiltInComponentType.transform] != nil)
        #expect(editedEntity.components[EditorBuiltInComponentType.sprite] != nil)
        #expect(editedEntity.components[EditorBuiltInComponentType.visibility] != nil)

        let content = try model.encodedYAML()
        let decoded = try EditorSceneModel.decode(from: content)
        #expect(decoded.entities.count == 2)
        #expect(decoded.editor?.selectedEntity == entity.id)
    }

    @Test("scene hierarchy builds visible rows with components and resources")
    func sceneHierarchyBuildsVisibleRows() throws {
        var model = EditorSceneModel.default(projectName: "Hierarchy")
        let parent = model.addEntity(name: "Player")
        let child = model.addEntity(name: "Sprite")
        let childIndex = try #require(model.entities.firstIndex { $0.id == child.id })
        model.entities[childIndex].components[EditorBuiltInComponentType.sprite] = EditorComponentRegistry.defaultPayload(for: EditorBuiltInComponentType.sprite)
        model.entities[childIndex].components[EditorBuiltInComponentType.sprite]?["texture"] = .string("Assets/Textures/player.png")
        model.selectEntity(model.entities[childIndex].id)

        let items = EditorSceneHierarchyModel.visibleItems(for: model)
        let childItem = try #require(items.first { $0.id == child.id })

        #expect(items.map(\.name).contains("Root"))
        #expect(childItem.level == 2)
        #expect(child.parent == parent.id)
        #expect(childItem.componentNames.contains("Sprite"))
        #expect(childItem.resources == [
            EditorSceneHierarchyResource(componentName: "Sprite", fieldName: "Texture", value: "Assets/Textures/player.png")
        ])
    }

    @Test("scene model expands ancestors when selecting child entity")
    func sceneModelExpandsSelectedEntityAncestors() throws {
        var model = EditorSceneModel.default(projectName: "Expanded")
        let rootID = try #require(model.entities.first?.id)
        let parent = model.addEntity(name: "Parent")
        let child = model.addEntity(name: "Child")
        model.editor?.expandedEntities = []

        model.selectEntity(child.id)

        #expect(model.editor?.selectedEntity == child.id)
        #expect(model.editor?.expandedEntities == [rootID, parent.id, child.id])
    }

    @Test("component field edits update runtime component through scene loader")
    @MainActor
    func componentFieldEditUpdatesRuntimeWorld() throws {
        var model = EditorSceneModel.default(projectName: "Runtime")
        let rootID = try #require(model.entities.first?.id)
        let transformDescriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.transform))
        let positionField = try #require(transformDescriptor.fields.first { $0.key == "position" })
        model.updateField(typeName: EditorBuiltInComponentType.transform, field: positionField, value: "10, 20, 0", in: rootID)

        let world = World()
        let result = EditorSceneFileLoader.load(model: model, into: world)
        let entityID = try #require(result.entitiesByEditorID[rootID])
        let transform = try #require(world.get(Transform.self, from: entityID))

        #expect(transform.position == Vector3(10, 20, 0))
    }

    @Test("picking helpers use 2D fallback bounds and nearest 3D ray hit")
    func pickingMath() throws {
        let transform = Transform(position: Vector3(2, 3, 0))
        #expect(EditorPicking.contains2D(Vector2(2.1, 3.1), transform: transform, bounds: nil))
        #expect(!EditorPicking.contains2D(Vector2(4, 3), transform: transform, bounds: nil))

        let ray = Ray(origin: Vector3(0, 0, -5), direction: Vector3(0, 0, 1))
        let aabb = AABB(center: .zero, halfExtents: Vector3(1, 1, 1))
        let distance = try #require(EditorPicking.rayAABBIntersectionDistance(ray: ray, aabb: aabb))
        #expect(distance == 4)
    }

    @Test("2D viewport grid and default entity marker render as quads")
    @MainActor
    func viewportGridAndMarkerRenderAsQuads() throws {
        let viewportModel = EditorSceneViewportModel()
        let content = try EditorSceneModel.default(projectName: "Viewport").encodedYAML()
        viewportModel.configure(sceneContent: content, onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in })

        var gridContext = UIGraphicsContext()
        viewportModel.drawGrid(in: &gridContext, size: Size(width: 320, height: 180), theme: .adaEditor)

        #expect(gridContext.getDrawCommands().contains { command in
            if case .drawQuad = command { return true }
            return false
        })

        var gizmoContext = UIGraphicsContext()
        viewportModel.drawGizmos(in: &gizmoContext, size: Size(width: 320, height: 180), theme: .adaEditor)

        #expect(gizmoContext.getDrawCommands().contains { command in
            if case .drawQuad = command { return true }
            return false
        })
    }

    @Test("viewport reloads edited scene content without recreating camera")
    @MainActor
    func viewportReloadsSceneContentInAttachedWorld() throws {
        var model = EditorSceneModel.default(projectName: "Reload")
        let initialContent = try model.encodedYAML()
        let world = World()
        let cameraEntity = world.spawn("SceneView_Camera") {
            Camera()
            Transform()
            CameraRenderGraph(subgraphLabel: "Scene 2D Render Graph", inputSlot: "view")
        }
        let viewportModel = EditorSceneViewportModel()
        let initialResult = EditorSceneFileLoader.load(content: initialContent, into: world)

        viewportModel.configure(sceneContent: initialContent, onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in })
        viewportModel.attachSceneWorld(world, loadResult: initialResult)

        _ = model.addEntity(name: "Reloaded")
        let updatedContent = try model.encodedYAML()
        let reloadResult = try #require(viewportModel.configure(sceneContent: updatedContent, onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in }))
        let sceneEntities = world.getEntities().filter { $0.id != cameraEntity.id }

        #expect(reloadResult.entityCount == model.entities.count)
        #expect(world.getEntityByID(cameraEntity.id) === cameraEntity)
        #expect(sceneEntities.count == model.entities.count)
        #expect(sceneEntities.contains { $0.name == "Reloaded" })
    }

    @Test("viewport mode updates camera render graph")
    @MainActor
    func viewportModeUpdatesCameraRenderGraph() throws {
        let world = World()
        let cameraEntity = world.spawn("SceneView_Camera") {
            Camera()
            Transform()
            CameraRenderGraph(subgraphLabel: "Scene 2D Render Graph", inputSlot: "view")
        }
        let viewportModel = EditorSceneViewportModel()

        viewportModel.attachSceneWorld(world, loadResult: .empty)
        viewportModel.setViewportSize(Size(width: 640, height: 360))
        viewportModel.setDisplayMode(.threeD)

        let threeDGraph = try #require(cameraEntity.components[CameraRenderGraph.self])
        #expect(threeDGraph.subgraphLabel.rawValue == "Scene 3D Render Graph")

        viewportModel.setDisplayMode(.twoD)

        let twoDGraph = try #require(cameraEntity.components[CameraRenderGraph.self])
        #expect(twoDGraph.subgraphLabel.rawValue == "Scene 2D Render Graph")
    }
}
