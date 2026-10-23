@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Foundation
import Testing

@testable import AdaEditor

@MainActor @Suite("Shader Graph workbench", .serialized) struct EditorShaderGraphWorkbenchTests {
    @Test func templatesCompileAndRouteAsGraphAssets() throws {
        for kind in [EditorNewFileKind.spriteShaderGraph, .pbrShaderGraph, .dissolveShaderGraph, .uvScrollShaderGraph] {
            let content = kind.initialContent(fileName: "Effect.shadergraph")
            let graph = try JSONDecoder().decode(ShaderGraph.self, from: Data(content.utf8))
            try graph.compileGLSL().validateGLSL()
            #expect(EditorViewModel.fileKind(for: URL(fileURLWithPath: "/Effect.shadergraph"), isDirectory: false) == .genericAsset)
            #expect(EditorViewModel.assetPreviewKind(for: .genericAsset, fileExtension: "shadergraph") == .shaderGraph)
        }
    }

    @Test func workbenchSharesHistorySavesAllAndProtectsAnExternallyChangedFile() throws {
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let document = document(url)
        let workbench = EditorWorkbenchViewModel(openDocuments: [.asset(document)], activeDocumentID: document.id)
        let model = workbench.shaderGraphModel(for: document)
        #expect(workbench.shaderGraphModel(for: document) === model)
        model.moveNode("tint", to: .init(x: 85, y: 95))
        #expect(workbench.activeDocument?.isDirty == true)
        #expect(workbench.performDocumentHistory(redo: false))
        #expect(workbench.activeDocument?.isDirty == false)
        #expect(workbench.performDocumentHistory(redo: true))
        #expect(workbench.saveAllDocuments())
        #expect(!model.isDirty)
        #expect(EditorShaderGraphModel(url: url).graph?.layout["tint"] == .init(x: 85, y: 95))
        model.moveNode("tint", to: .init(x: 90, y: 100))
        let external = Data(EditorShaderGraphTemplates.initialContent(target: .sprite).utf8)
        try external.write(to: url)
        workbench.closeDocument(id: document.id)
        #expect(workbench.openDocuments.count == 1)
        #expect(model.isDirty)
        #expect(try Data(contentsOf: url) == external)
    }

    @Test func actualCanvasPointerEventsMoveAndConnectWithUndo() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World()))
        }
        let url = try fixture()
        defer { try? FileManager.default.removeItem(at: url) }
        let model = EditorShaderGraphModel(url: url)
        model.editNode("output") { $0.inputs = [:] }
        let state = EditorNodeCanvasState()
        let interaction = model.canvasInteraction()
        let root = UIContainerView(rootView: EditorNodeCanvas(items: model.canvasItems, wires: model.canvasWires, selection: model.selection, state: state, interaction: interaction))
        root.frame = Rect(x: 40, y: 30, width: 1000, height: 600)
        root.bounds.size = root.frame.size
        root.layoutIfNeeded()
        let canvasFrame = try root.uiNode(matching: .accessibilityIdentifier("AdaEditor.NodeCanvas")).absoluteFrame
        let geometry = EditorNodeCanvasGeometry(nodes: model.canvasItems, pan: state.pan, zoom: state.zoom)
        let source = try #require(geometry.port(.init(node: "tint", port: "value", isOutput: true)))
        let target = try #require(geometry.port(.init(node: "output", port: "baseColor", isOutput: false)))
        func point(_ value: Vector2) -> Point { .init(value.x + canvasFrame.minX, value.y + canvasFrame.minY) }
        for (value, phase) in [(source, MouseEvent.Phase.began), (target, .changed), (target, .ended)] { root.onMouseEvent(mouse(point(value), phase)) }
        #expect(model.graph?.nodes.last?.inputs["baseColor"] == .init("tint"))
        let start = geometry.screen([60, 195])
        for (value, phase) in [(start, MouseEvent.Phase.began), (start + Vector2(50, 20), .changed), (start + Vector2(50, 20), .ended)] { root.onMouseEvent(mouse(point(value), phase)) }
        #expect(model.graph?.layout["tint"] == .init(x: 80, y: 200))
        #expect(model.selection == ["tint"])
        model.undo()
        #expect(model.graph?.layout["tint"] == .init(x: 30, y: 180))
    }

    private func mouse(_ point: Point, _ phase: MouseEvent.Phase) -> MouseEvent { .init(window: .empty, button: .left, mousePosition: point, phase: phase, modifierKeys: [], time: 0) }

    private func fixture() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("GraphWorkbench-\(UUID().uuidString).shadergraph")
        try Data(EditorShaderGraphTemplates.initialContent(target: .pbrSurface).utf8).write(to: url)
        return url
    }

    private func document(_ url: URL) -> EditorAssetDocument {
        .init(
            id: "asset:Effect.shadergraph",
            title: "Effect.shadergraph",
            relativePath: "Effect.shadergraph",
            absolutePath: url.path,
            assetReference: nil,
            kind: .shaderGraph,
            fileExtension: "shadergraph",
            byteCount: nil,
            modifiedAt: nil,
            errorMessage: nil
        )
    }
}
