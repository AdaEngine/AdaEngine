@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaRender
@_spi(Internal) @testable import AdaUI
import Foundation
import Math
import Testing

@testable import AdaEditor

@MainActor
@Suite("Asset tab switching", .serialized)
struct EditorAssetTabSwitchingTests {
    init() throws {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            try RenderEngine.setupRenderEngine()
        }
    }

    @Test("Selecting another asset replaces its preview and returning reloads the original", arguments: [false, true])
    func switchesAssetPreview(models: Bool) async throws {
        let engine = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let paths = models
            ? ["Tests/AdaAssetsTests/Fixtures/vox/robot.vox", "Tests/AdaAssetsTests/Fixtures/vox/castle.vox"]
            : ["Tests/AdaUITests/Fixtures/KenneyUI/normal.png", "Tests/AdaUITests/Fixtures/KenneyUI/pressed.png"]
        let documents = paths.map { path -> EditorWorkbenchDocument in
            let url = engine.appendingPathComponent(path)
            return .asset(EditorAssetDocument(
                id: "asset:\(path)", title: url.lastPathComponent, relativePath: path,
                absolutePath: url.path, assetReference: nil, kind: models ? .model3D : .image,
                fileExtension: url.pathExtension
            ))
        }
        let workbench = EditorWorkbenchViewModel(openDocuments: documents, activeDocumentID: documents[0].id)
        let container = makeContainer(workbench)
        container.frame = Rect(x: 0, y: 0, width: 900, height: 600)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let identifier = models ? "AdaEditor.ModelPreview.Viewport" : "AdaEditor.AssetPreview.Canvas"
        let initial = try await preview(identifier, in: container)

        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Tab.Select.\(documents[1].id)"))
        let second = try await preview(identifier, in: container, excluding: initial)
        #expect(workbench.activeDocumentID == documents[1].id)
        #expect(second !== initial)

        _ = try container.uiTapNode(matching: .accessibilityIdentifier("AdaEditor.Tab.Select.\(documents[0].id)"))
        let returned = try await preview(identifier, in: container, excluding: second)
        #expect(workbench.activeDocumentID == documents[0].id)
        #expect(returned !== second)
    }

    private func preview<Content: View>(_ identifier: String, in container: UIContainerView<Content>, excluding previous: ViewNode? = nil) async throws -> ViewNode {
        for _ in 0..<300 {
            try await Task.sleep(for: .milliseconds(10))
            container.update(1.0 / 60.0)
            container.layoutIfNeeded()
            if let node = container.viewTree.rootNode.findNodyByAccessibilityIdentifier(identifier), node !== previous {
                return node
            }
        }
        return try #require(container.viewTree.rootNode.findNodyByAccessibilityIdentifier(identifier))
    }

    private func makeContainer(_ workbench: EditorWorkbenchViewModel) -> UIContainerView<EditorCenterWorkbench> {
        UIContainerView(rootView: EditorCenterWorkbench(
            viewModel: workbench, inspectorViewModel: EditorInspectorSidebarViewModel(), playModeState: .editing,
            scenePlayRuntime: nil, sceneResourceRootURL: nil, onPlayScene: nil, onStopScene: nil, onSceneEntitySelected: nil,
            onSourceHover: nil, onGoToDefinition: nil, onCompletionPosition: nil, onCompletionRequest: nil,
            onApplyCompletion: nil, onMoveCompletionSelection: nil, onAcceptCompletion: nil,
            onTextSelection: nil, onChatSelection: nil, sourceContextMenuItems: nil,
            onSelectDocument: nil, onRevealDocument: nil, onCopyDocumentPath: nil, onSelectPreview: nil,
            onRebuildPreview: nil, onHidePreview: nil, onShowPreviewBuildOutput: nil
        ))
    }
}
