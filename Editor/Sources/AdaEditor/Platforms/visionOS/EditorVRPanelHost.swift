#if os(visionOS)
    import AdaEngine
    import AdaEngineEmbeddable
    import SwiftUI

    @available(visionOS 26.0, *)
    struct EditorVRPanelHost<Content: AdaEngine.View>: SwiftUI.View {
        let workspace: EditorVRWorkspace
        let panel: EditorVRPanel
        let width: Double
        let height: Double
        let content: Content
        @SwiftUI.State private var wideResizeRequest = 0
        @SwiftUI.Environment(\.dismissWindow) private var dismissWindow

        init(
            workspace: EditorVRWorkspace,
            panel: EditorVRPanel,
            width: Double,
            height: Double,
            @AdaEngine.ViewBuilder content: () -> Content
        ) {
            self.workspace = workspace
            self.panel = panel
            self.width = width
            self.height = height
            self.content = content()
        }

        var body: some SwiftUI.View {
            if workspace.project == nil {
                SwiftUI.Color.clear.onAppear { dismissWindow(id: panel.windowID) }
            } else {
                hostedPanel
            }
        }

        private var showsStudioOrnaments: Bool { [.studio, .files, .code].contains(panel) }
        private var isWorkbench: Bool { [.studio, .files, .code, .settings].contains(panel) }

        private var hostedPanel: some SwiftUI.View {
            AdaUIHost(assetBundle: .editor, onError: { workspace.message = $0.localizedDescription },
                onTextInputFocusChanged: { workspace.setTextInputFocus($0, host: panel.windowID) }) {
                content
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                    .environment(\.theme, .adaEditor)
            }
            .frame(
                minWidth: isWorkbench ? 1000 : min(width, 320), idealWidth: width, maxWidth: isWorkbench ? 2800 : max(width * 2, 720),
                minHeight: isWorkbench ? 600 : min(height, 240), idealHeight: height, maxHeight: 1600
            )
            .glassBackgroundEffect(in: SwiftUI.RoundedRectangle(cornerRadius: 24))
            .background {
                EditorVRWindowResize(request: wideResizeRequest, size: CGSize(width: 2200, height: 900), onError: { workspace.message = $0.localizedDescription })
                    .frame(width: 0, height: 0)
            }
            .modifier(EditorVRStudioOrnaments(workspace: workspace, visible: showsStudioOrnaments,
                resize: { wideResizeRequest += 1 }, enter: nil))
            .onAppear { workspace.setPanel(panel, visible: true) }
            .onHover { workspace.setPanelHover($0, panel: panel) }
            .onDisappear {
                workspace.setPanel(panel, visible: false)
                workspace.setPanelHover(false, panel: panel)
                workspace.setTextInputFocus(false, host: panel.windowID)
            }
        }
    }
#endif
