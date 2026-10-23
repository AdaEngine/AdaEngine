@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Testing

@testable import AdaEditor

@MainActor @Suite("Shader Graph organization", .serialized) struct EditorShaderGraphOrganizationTests {
    @Test func clipboardRemapsNodesAndOneUndoRemovesThePaste() throws {
        let (model, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        model.selection = ["sprite", "tint", "multiply"]
        model.groupSelection()
        let payload = try #require(model.copySelection())
        let count = model.graph?.nodes.count
        #expect(model.paste(payload, at: [800, 200]))
        #expect(model.graph?.nodes.count == (count ?? 0) + 3)
        #expect(model.selection.isDisjoint(with: ["sprite", "tint", "multiply"]))
        let selected = try #require(model.graph).nodes.filter { model.selection.contains($0.id) }
        #expect(selected.flatMap { $0.inputs.values }.allSatisfy { model.selection.contains($0.node) })
        #expect(model.graph?.groups.count == 2)
        model.undo()
        #expect(model.graph?.nodes.count == count)
        #expect(!model.paste("{}", at: .zero))
    }

    @Test func typedSearchConnectsItsNewNodeInOneTransaction() throws {
        let (model, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let search = EditorShaderGraphSearch()
        search.open(at: [400, 300], endpoint: .init(node: "tint", port: "value", isOutput: true))
        let graph = try #require(model.graph)
        #expect(!search.entries(in: graph).contains { $0.operation == .time || $0.operation == .noise2D })
        let entry = try #require(search.entries(in: graph).first { $0.operation == .multiply && $0.type == .color })
        model.insert(entry, using: search)
        let added = try #require(model.selectedNode)
        #expect(added.inputs.values.contains(.init("tint")))
        model.undo()
        #expect(model.graph == graph)
    }

    @Test func layoutGroupsAndCommentsDoNotRecompileAndSurviveSave() throws {
        let (model, url) = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let revision = model.semanticRevision
        model.selection = ["sprite", "tint"]
        model.groupSelection()
        model.addComment(at: [100, 500])
        #expect(model.semanticRevision == revision)
        #expect(model.canvasDecorations.count == 2)
        #expect(model.save())
        let reopened = EditorShaderGraphModel(url: url)
        #expect(reopened.graph?.groups == model.graph?.groups)
        #expect(reopened.graph?.notes == model.graph?.notes)
        model.removeSelection()
        #expect(model.graph?.groups.isEmpty == true)
    }

    @Test func focusedCanvasKeysDoNotInterceptSiblingTextInput() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
        var presses = 0
        let root = UIContainerView(
            rootView: VStack {
                RectangleShape().fill(Color.blue).frame(height: 80).onFocusedKeyEvent { _ in presses += 1 }.accessibilityIdentifier("canvas")
                TextField("Name", text: Binding(get: { "" }, set: { _ in })).frame(height: 40).accessibilityIdentifier("field")
            }
        )
        root.frame = Rect(x: 0, y: 0, width: 300, height: 160)
        root.bounds.size = root.frame.size
        root.layoutIfNeeded()
        _ = try root.uiTapNode(matching: .accessibilityIdentifier("canvas"))
        root.onKeyEvent(KeyEvent(window: .empty, keyCode: .space, modifiers: [], status: .down, time: 0, isRepeated: false))
        #expect(presses == 1)
        _ = try root.uiTapNode(matching: .accessibilityIdentifier("field"))
        root.onKeyEvent(KeyEvent(window: .empty, keyCode: .space, modifiers: [], status: .down, time: 1, isRepeated: false))
        #expect(presses == 1)
    }

    private func fixture() throws -> (EditorShaderGraphModel, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GraphOrganization-\(UUID().uuidString).shadergraph")
        try Data(EditorShaderGraphTemplates.initialContent(target: .sprite).utf8).write(to: url)
        return (EditorShaderGraphModel(url: url), url)
    }
}
