@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import Foundation
import Math
import Testing

@MainActor @Suite(.serialized)
struct EditorScriptUIBindingTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "UI binding inspector")))
        }
    }

    @Test func inspectorAddsBindingAndSceneReloadPreservesIt() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("HUD.ui")
        let document = UISceneDocument(root: .init(type: "Text", arguments: ["text": .init(binding: "title")]),
                                       inputs: [.init("title", type: .string, defaultValue: .string("Preview"))])
        try document.encodedYAML().write(to: url, atomically: true, encoding: .utf8)
        var scene = EditorSceneModel.default(projectName: "Bindings")
        let entityID = scene.addEntity(name: "HUD", parentID: nil).id
        let typeName = EditorBuiltInComponentType.uiComponent
        scene.addComponent(typeName: typeName, to: entityID)
        let descriptor = try #require(EditorComponentRegistry.descriptor(named: typeName))
        let pathField = try #require(descriptor.fields.first { $0.key == "path" })
        scene.updateField(typeName: typeName, field: pathField, value: "@res://HUD.ui", in: entityID)
        let viewModel = EditorInspectorSidebarViewModel()
        viewModel.uiSceneFiles = ["@res://HUD.ui": url.path]
        viewModel.selectEntity(.init(
            editorID: entityID, name: "HUD", componentNames: [typeName], transformFields: [],
            components: [.init(typeName: typeName, displayName: "UI Component", fields: descriptor.fields.map {
                .init(typeName: typeName, field: $0, value: $0.key == "path" ? "@res://HUD.ui" : ($0.key == "scriptBindings" ? "{}" : ""))
            }, canRemove: true)], addableComponents: [],
            scriptableObjects: [.init(identifier: "game.hud", displayName: "HUD", fields: [
                .init(typeName: "game.hud", field: .init(key: "title", label: "Title", kind: .string), value: "Hello")
            ])], gizmo: nil, hasExplicitGizmo: false
        ))
        viewModel.updateComponentField = { typeName, field, value in
            scene.updateField(typeName: typeName, field: field, value: value, in: entityID)
        }
        let bindingField = try #require(viewModel.selectedEntity?.components.first?.fields.first { $0.field.key == "scriptBindings" })
        let container = UIContainerView(rootView: EditorInspectorSidebar(viewModel: viewModel).scriptUIBindingsEditor(bindingField))
        container.frame = Rect(x: 0, y: 0, width: 340, height: 400)
        container.layoutSubviews()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIBinding.Add"))
        let expected = UIScriptFieldBinding(script: "game.hud", field: "title")
        #expect(viewModel.uiScriptBindings == ["title": expected])
        #expect(viewModel.uiBindingIssue(input: "title", mapping: expected) == nil)
        let world = World(name: "Persisted binding")
        let result = EditorSceneFileLoader.load(content: try scene.encodedYAML(), into: world, loadsScriptableObjects: false, resourceRootURL: root)
        #expect(result.warnings.isEmpty)
        let ui = try #require(world.getEntities().compactMap { $0.components[UIComponent.self] }.first)
        #expect(ui.source?.scriptBindings == ["title": expected])
        viewModel.setUIBinding("title", to: .init(script: "missing", field: "title"))
        #expect(viewModel.uiBindingIssue(input: "title", mapping: .init(script: "missing", field: "title")) != nil)
        viewModel.setUIBinding("title", to: nil)
        #expect(viewModel.uiScriptBindings.isEmpty)
    }
}
