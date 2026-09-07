@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Testing

@MainActor
@Suite(.serialized)
struct EditorInspectorRefreshTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "InspectorRefreshTests")))
        }
    }

    @Test("field edits preserve component nodes, focus, and scroll position", arguments: [
        (EditorBuiltInComponentType.transform, "position", "10, 20, 30"),
        (EditorBuiltInComponentType.sprite, "tintColor", "0.5, 0.4, 0.8, 1"),
        (EditorBuiltInComponentType.sprite, "flipX", "true"),
        (EditorBuiltInComponentType.sprite, "size", "64, 48"),
        (EditorBuiltInComponentType.visibility, "value", "hidden")
    ])
    func editingPreservesComponentNodes(typeName: String, fieldKey: String, value: String) async throws {
        var scene = EditorSceneModel.default(projectName: "Inspector")
        let entity = scene.addEntity(preset: .sprite)
        let viewport = EditorSceneViewportModel()
        let inspector = EditorInspectorSidebarViewModel()
        viewport.configure(
            sceneContent: try scene.encodedYAML(),
            onSelectionChanged: { [weak inspector] in inspector?.selectEntity($0) },
            onDocumentContentChanged: { _ in }
        )
        let container = UIContainerView(rootView: EditorInspectorSidebar(viewModel: inspector))
        container.frame = Rect(x: 0, y: 0, width: 360, height: 600)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let selector = UINodeSelector.accessibilityIdentifier("AdaEditor.Inspector.ToggleComponent.\(EditorBuiltInComponentType.transform)")
        _ = try container.uiScrollToNode(matching: selector)
        let initialNodes = componentHeaders(in: container.uiTreeRoots())
        let textField = try #require(flatten(container.uiTreeRoots()).first {
            $0.nodeType.contains("TextFieldViewNode") && $0.canBecomeFocused
        })
        _ = try container.uiFocusNode(matching: .runtimeID(textField.runtimeId))
        let field = try #require(inspector.selectedEntity?.components
            .first { $0.typeName == typeName }?.fields.first { $0.field.key == fieldKey })
        inspector.updateComponentField = { typeName, field, value in
            scene.updateField(typeName: typeName, field: field, value: value, in: entity.id)
            do {
                viewport.configure(
                    sceneContent: try scene.encodedYAML(),
                    onSelectionChanged: { [weak inspector] in inspector?.selectEntity($0) },
                    onDocumentContentChanged: { _ in }
                )
            } catch {
                Issue.record(error)
            }
        }
        inspector.componentFieldBinding(typeName: typeName, field: field.field).wrappedValue = value
        for _ in 0..<10 {
            try await Task.sleep(for: .milliseconds(1))
            container.update(1.0 / 60.0)
            container.layoutIfNeeded()
            let updatedNodes = componentHeaders(in: container.uiTreeRoots())
            #expect(updatedNodes.map(\.runtimeId) == initialNodes.map(\.runtimeId))
            #expect(updatedNodes.map(\.absoluteFrame) == initialNodes.map(\.absoluteFrame))
            #expect(try container.uiNode(matching: .runtimeID(textField.runtimeId)).isFocused)
        }
        #expect(inspector.selectedEntity?.editorID == entity.id)
        #expect(inspector.componentFieldBinding(typeName: typeName, field: field.field).wrappedValue == value)
        let persisted = try EditorSceneModel.decode(from: scene.encodedYAML())
        let payload = try #require(persisted.entities.first { $0.id == entity.id }?.components[typeName])
        #expect(field.field.displayValue(in: payload) == value)
    }

    private func componentHeaders(in nodes: [UINodeSnapshot]) -> [UINodeSnapshot] {
        flatten(nodes).filter {
            $0.accessibilityIdentifier?.hasPrefix("AdaEditor.Inspector.ToggleComponent.") == true
        }
    }

    private func flatten(_ nodes: [UINodeSnapshot]) -> [UINodeSnapshot] {
        nodes.flatMap { [$0] + flatten($0.children) }
    }
}
