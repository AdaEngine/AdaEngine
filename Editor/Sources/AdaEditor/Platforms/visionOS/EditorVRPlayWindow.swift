#if os(visionOS)
    import AdaEngine
    import AdaEngineEmbeddable
    import SwiftUI

    @available(visionOS 26.0, *)
    struct EditorVRPlayWindow: SwiftUI.View {
        let workspace: EditorVRWorkspace
        @SwiftUI.Environment(\.dismissWindow) private var dismissWindow

        var body: some SwiftUI.View {
            if let play = workspace.playSession {
                AdaUIHost(assetBundle: .editor, onError: { error in
                    workspace.stopPlay(id: play.id)
                    workspace.message = error.localizedDescription
                    workspace.studio?.workspaceStatus = .failed(error.localizedDescription)
                    workspace.studio?.appendOutput("Play failed: \(error.localizedDescription)")
                }) {
                    play.runtime
                        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
                        .environment(\.theme, .adaEditor)
                }
                .id(play.id)
                .frame(minWidth: 640, idealWidth: 1024, maxWidth: 2800, minHeight: 420, idealHeight: 720, maxHeight: 1600)
                .glassBackgroundEffect(in: SwiftUI.RoundedRectangle(cornerRadius: 24))
                .ornament(attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
                    SwiftUI.Button {
                        workspace.studio?.stopFromToolbar()
                    } label: {
                        SwiftUI.Label(L10n.text("Stop"), systemImage: "stop.fill")
                    }
                    .accessibilityIdentifier("AdaEditor.VR.Play.Stop")
                    .buttonStyle(.borderless).controlSize(.large)
                    .padding(14).glassBackgroundEffect(in: SwiftUI.Capsule()).padding(.top, 16)
                }
                .onDisappear { workspace.stopPlay(id: play.id) }
            } else {
                SwiftUI.Color.clear.onAppear { dismissWindow(id: EditorVRPlaySession.windowID) }
            }
        }
    }
#endif
