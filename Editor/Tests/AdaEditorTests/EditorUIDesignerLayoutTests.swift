@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) import AdaUI
import Math
import Testing

@Suite("UI Designer workspace", .serialized)
@MainActor
struct EditorUIDesignerLayoutTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            let worlds = AppWorlds(main: World(name: "DesignerLayoutTests"))
            RenderWorldPlugin().setup(in: worlds)
        }
    }

    @Test func compactWorkspaceKeepsCanvasAndSwitchesPanels() throws {
        let model = EditorUISceneModel(content: try UISceneDocument().encodedYAML(), sourceURL: nil, resourceRoot: nil)
        let container = makeContainer(model, size: Size(width: 768, height: 700))
        let artboard = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Artboard"))
        #expect(artboard.absoluteFrame.width > 300)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Pane.Library"))
        container.layoutIfNeeded()
        _ = try container.uiScrollToNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Add.Text"))
        container.layoutIfNeeded()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Add.Text"))
        #expect(model.document.root.children.first?.type == "Text")
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Pane.Inspector"))
        container.layoutIfNeeded()
        _ = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Parameter.text"))
    }

    @Test func modifierLibraryIsExplicitAndAddsRealModifier() throws {
        let model = EditorUISceneModel(content: try UISceneDocument().encodedYAML(), sourceURL: nil, resourceRoot: nil)
        let container = makeContainer(model, size: Size(width: 1440, height: 900))
        #expect(throws: (any Error).self) { try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Modifiers.Library")) }
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Modifiers.Toggle"))
        container.layoutIfNeeded()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Modifier.Add.background"))
        #expect(model.document.root.modifiers.first?.type == "background")
    }

    @Test func fittingScalesRenderingWithoutChangingLayoutSize() {
        let preview = UIView(frame: .zero)
        let host = EditorPreviewHostView(frame: Rect(x: 0, y: 0, width: 400, height: 300))
        host.bounds.size = Size(width: 400, height: 300)
        host.configure(previewView: preview, zoom: 0.5, isInteractive: false, contentSize: Size(width: 800, height: 600))
        host.layoutSubviews()
        #expect(preview.frame.size == Size(width: 800, height: 600))
        #expect(host.previewPoint(from: Point(100, 75)) == Point(200, 150))
    }

    @Test func emptyCanvasActionAndLayerSelectionRemainConnected() throws {
        let model = EditorUISceneModel(content: try UISceneDocument().encodedYAML(), sourceURL: nil, resourceRoot: nil)
        let container = makeContainer(model, size: Size(width: 1440, height: 900))
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Empty.AddText"))
        #expect(model.document.root.children.count == 1)
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Library.Layers"))
        container.layoutIfNeeded()
        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.UIScene.Node.\(model.document.root.id)"))
        #expect(model.selectedID == model.document.root.id)
    }

    @Test func fitSupportsLargeDocuments() {
        let layout = EditorUIDesignerLayout(size: Size(width: 1280, height: 790))
        let zoom = layout.fitZoom(width: 8192, height: 8192)
        #expect(zoom < 0.25)
        #expect(8192 * zoom <= layout.canvasWidth)
        #expect(8192 * zoom <= layout.contentHeight)
    }

    private func makeContainer(_ model: EditorUISceneModel, size: Size) -> UIContainerView<EditorUISceneEditor> {
        let container = UIContainerView(rootView: EditorUISceneEditor(model: model))
        container.frame = Rect(origin: .zero, size: size)
        container.bounds.size = size
        container.layoutIfNeeded()
        return container
    }
}
