@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Foundation
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

    @Test("scene creation presets add useful component sets")
    func sceneCreationPresetsAddComponents() throws {
        var model = EditorSceneModel.default(projectName: "Presets")

        let camera = model.addEntity(preset: .camera)
        let sprite = model.addEntity(preset: .sprite)
        let light = model.addEntity(preset: .light2D)

        #expect(model.entities.first { $0.id == camera.id }?.components[EditorBuiltInComponentType.camera] != nil)
        #expect(model.entities.first { $0.id == sprite.id }?.components[EditorBuiltInComponentType.sprite] != nil)
        #expect(model.entities.first { $0.id == sprite.id }?.components[EditorBuiltInComponentType.visibility] != nil)
        #expect(model.entities.first { $0.id == light.id }?.components[EditorBuiltInComponentType.light2D] != nil)
    }

    @Test("AdaScript scriptable objects round-trip through scene YAML and runtime loading")
    @MainActor
    func scriptableObjectsRoundTripThroughSceneRuntime() throws {
        let fileManager = FileManager.default
        let projectURL = fileManager.temporaryDirectory
            .appendingPathComponent("EditorScriptables-\(UUID().uuidString)", isDirectory: true)
        defer { try? fileManager.removeItem(at: projectURL) }
        let sourcesURL = projectURL.appendingPathComponent("Sources", isDirectory: true)
        try fileManager.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        let identifier = "editor.test.\(UUID().uuidString)"
        try """
        @scriptable(id: "\(identifier)", version: 2)
        class SceneController {
            @export var speed = 4.5;
            @export var enabled = true;
            @component(required: true) var transform: Transform;
        }
        """.write(to: sourcesURL.appendingPathComponent("SceneController.ada"), atomically: true, encoding: .utf8)
        let project = ProjectSystem.defaultProject(projectName: "ScriptableScene", buildSystem: .adaScript)
        let support = try EditorScriptableObjectCatalogLoader.load(project: project, at: projectURL, fileManager: fileManager)
        let descriptor = try #require(support.descriptors.first)
        var model = EditorSceneModel.default(projectName: "ScriptableScene")
        let entityID = try #require(model.editor?.selectedEntity)

        model.addScriptableObject(descriptor, to: entityID)
        model.updateScriptableObjectField(
            identifier: identifier,
            field: EditorComponentField(key: "speed", label: "speed", kind: .float),
            value: "9.25",
            in: entityID
        )
        let decodedModel = try EditorSceneModel.decode(from: model.encodedYAML())
        var app = AppWorlds(main: World(name: "EditorScriptableSceneRuntime"))
        EditorComponentRegistry.registerBuiltIns()
        app.addPlugin(ScriptableObjectPlugin())
        try support.playRuntime.install(in: &app)
        let loadResult = EditorSceneFileLoader.load(model: decodedModel, into: app.main)
        let runtimeEntityID = try #require(loadResult.entitiesByEditorID[entityID])
        let scripts = try #require(app.main.get(ScriptableComponents.self, from: runtimeEntityID)?.scripts)

        #expect(support.descriptors.map(\.identifier) == [identifier])
        #expect(scripts.count == 1)
        #expect(loadResult.warnings.isEmpty)
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

        let centerRay = EditorPicking.perspectiveRay(
            point: Point(x: 640, y: 360),
            viewportSize: Size(width: 1280, height: 720),
            cameraPosition: Vector3(0, 0, -5),
            front: Vector3(0, 0, 1),
            right: Vector3(1, 0, 0),
            verticalFieldOfView: .degrees(62)
        )
        #expect(centerRay.direction == Vector3(0, 0, 1))
    }

    @Test("3D viewport raycast selects the nearest scene entity")
    @MainActor
    func viewportRaycastSelectsNearestEntity() throws {
        let cameraPosition = Vector3(0, 6, -10)
        let front = Vector3(0, Math.sin(-0.42), Math.cos(-0.42)).normalized
        var model = EditorSceneModel.default(projectName: "Raycast")
        let entityID = try #require(model.editor?.selectedEntity)
        let transformDescriptor = try #require(EditorComponentRegistry.descriptor(named: EditorBuiltInComponentType.transform))
        let positionField = try #require(transformDescriptor.fields.first { $0.key == "position" })
        let targetPosition = cameraPosition + front * 10
        model.updateField(
            typeName: EditorBuiltInComponentType.transform,
            field: positionField,
            value: "\(targetPosition.x), \(targetPosition.y), \(targetPosition.z)",
            in: entityID
        )
        let content = try model.encodedYAML()
        let world = World()
        let camera = world.spawn("SceneView_Camera") {
            Camera()
            Transform()
        }
        let loadResult = EditorSceneFileLoader.load(content: content, into: world, loadsScriptableObjects: false)
        let viewportModel = EditorSceneViewportModel()
        viewportModel.configure(sceneContent: content, onSelectionChanged: { _ in }, onDocumentContentChanged: { _ in })
        viewportModel.attachSceneWorld(world, loadResult: loadResult)
        viewportModel.setViewportSize(Size(width: 1280, height: 720))
        viewportModel.setDisplayMode(.threeD)

        #expect(viewportModel.pick3D(at: Point(x: 640, y: 360)) == entityID)
        #expect(world.getEntityByID(camera.id) === camera)
    }

    @Test("scene viewport pill creates entities and starts Play Mode")
    @MainActor
    func sceneViewportPillControls() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let app = AppWorlds(main: World(name: "EditorSceneViewportPillTests"))
            RenderWorldPlugin().setup(in: app)
        }
        let content = try EditorSceneModel.default(projectName: "Pill").encodedYAML()
        let document = EditorSceneDocument(
            id: "scene:pill",
            title: "Pill.ascn",
            relativePath: "Assets/Scenes/Pill.ascn",
            absolutePath: nil,
            content: content,
            lastSavedContent: content,
            isReadOnly: false,
            sceneModel: EditorSceneFileLoader.model(from: content),
            errorMessage: nil,
            isDirty: false,
            statusMessage: nil,
            loadSummary: EditorSceneFileLoader.summary(from: content)
        )
        var updatedDocument: EditorSceneDocument?
        var didRequestPlay = false
        let container = UIContainerView(rootView: EditorSceneViewportView(
            document: document,
            inspectorViewModel: EditorInspectorSidebarViewModel(),
            playModeState: .editing,
            playRuntime: nil,
            onEntitySelected: nil,
            onPlay: { didRequestPlay = true },
            onStop: nil,
            onDocumentChanged: { updatedDocument = $0 }
        ))
        container.frame = Rect(x: 0, y: 0, width: 900, height: 600)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()

        _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.SceneViewport.Controls"))
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.SceneViewport.Create"))
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.SceneViewport.Control.Play"))

        #expect(updatedDocument?.sceneModel?.entities.count == 2)
        #expect(didRequestPlay)
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
