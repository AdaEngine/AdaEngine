import AdaEngine
import Foundation

struct EditorVRProjectPanel: View {
    let workspace: EditorVRWorkspace
    let openProject: () -> Void
    let createProject: () -> Void
    let enter: () -> Void
    let leave: () -> Void
    var enterMixed: (() -> Void)?
    var openPanel: ((EditorVRPanel) -> Void)?
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(workspace.project?.name ?? L10n.text("Ada Studio VR")).font(.system(size: 18, weight: .semibold)).lineLimit(2)
            Text((workspace.document?.title ?? L10n.text("No scene")) + " · " + workspace.saveStatus).font(.system(size: 14)).foregroundColor(theme.editorColors.muted)
            Button(workspace.isImmersed ? L10n.text("Leave Immersion") : L10n.text("Enter Immersive Editor"), action: workspace.isImmersed ? leave : enter)
                .disabled(workspace.isOpening || workspace.document == nil)
                .accessibilityIdentifier("AdaEditor.VR.Project.Enter")
            if !workspace.isImmersed, let enterMixed {
                Button(L10n.text("Mixed"), action: enterMixed)
                    .disabled(workspace.isOpening || workspace.document == nil)
                    .accessibilityIdentifier("AdaEditor.VR.Project.EnterMixed")
            }
            HStack(spacing: 18) {
                Button(L10n.text("Open Project"), action: openProject)
                Button(L10n.text("New Project"), action: createProject)
            }.disabled(!workspace.canChangeProject)
            if let openPanel {
                HStack(spacing: 14) {
                    Button(L10n.text("Editor")) { openPanel(.code) }
                    Button(L10n.text("Console")) { openPanel(.console) }
                    Button(L10n.text("Agent")) { openPanel(.agent) }
                    Button(L10n.text("Settings")) { openPanel(.settings) }
                }
            }
            Text(L10n.text("Scenes")).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.editorColors.muted)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if workspace.document == nil {
                        ForEach(workspace.recentProjects, id: \.id) { reference in
                            Button(reference.name) { workspace.openRecent(reference) }.disabled(!workspace.canChangeProject)
                        }
                    }
                    ForEach(workspace.scenes, id: \.path) { url in
                        Button(url.lastPathComponent) {
                            do { try workspace.openScene(at: url) } catch { workspace.message = error.localizedDescription }
                        }.disabled(!workspace.canChangeProject)
                    }
                }
            }.frame(maxHeight: 170)
            if let message = workspace.message {
                Text(message).font(.system(size: 14)).foregroundColor(theme.editorColors.muted).lineLimit(4)
            }
            Spacer()
        }.padding(20).foregroundColor(theme.editorColors.text).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct EditorVRNavigationPanel: View {
    let workspace: EditorVRWorkspace
    let moveViewer: (Vector3) -> Void
    let focusSelection: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(L10n.text("Move your viewpoint")).font(.system(size: 16, weight: .semibold))
            HStack(spacing: 18) {
                Button(L10n.text("Left")) { moveViewer([-1, 0, 0]) }
                Button(L10n.text("Forward")) { moveViewer([0, 0, 1]) }
                Button(L10n.text("Right")) { moveViewer([1, 0, 0]) }
            }
            HStack(spacing: 18) {
                Button(L10n.text("Up")) { moveViewer([0, 1, 0]) }
                Button(L10n.text("Back")) { moveViewer([0, 0, -1]) }
                Button(L10n.text("Down")) { moveViewer([0, -1, 0]) }
            }
            Button(L10n.text("Focus Selected"), action: focusSelection).disabled(workspace.selectedName == nil)
            Text(L10n.text("WASD to move · Mouse wheel / two-hand pinch to zoom")).font(.system(size: 13)).foregroundColor(theme.editorColors.muted)
            Spacer()
        }.padding(20).foregroundColor(theme.editorColors.text).disabled(!workspace.isImmersed || workspace.isManipulating)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

struct EditorVRAssetsPanel: View {
    let workspace: EditorVRWorkspace
    @State private var query = ""
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(L10n.text("Primitives")).font(.system(size: 13, weight: .semibold)).foregroundColor(theme.editorColors.muted)
            HStack(spacing: 12) {
                ForEach(EditorVRPrimitive.allCases, id: \.rawValue) { primitive in
                    EditorVRDockButton(title: primitive.rawValue, symbol: "\u{E3A5}") { workspace.addPrimitive(primitive) }
                        .disabled(!workspace.canEdit).accessibilityIdentifier("AdaEditor.VR.Add.\(primitive.rawValue)")
                }
            }
            TextField(L10n.text("Search project models"), text: $query).font(.system(size: 15))
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if workspace.modelAssets.isEmpty {
                        Text(L10n.text("No imported models in this project yet.")).font(.system(size: 14)).foregroundColor(theme.editorColors.muted)
                    }
                    ForEach(workspace.modelAssets.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }, id: \.id) { asset in
                        HStack(spacing: 12) {
                            Text("\u{E3A5}").font(AdaEditorMaterialSymbolFont.font(size: 26)).foregroundColor(theme.editorColors.blue)
                            Text(asset.title).font(.system(size: 15)).lineLimit(2)
                            Spacer()
                            Button(action: { workspace.addAsset(asset) }) {
                                Text(L10n.text("Add")).font(.system(size: 14, weight: .semibold)).frame(width: 52, height: 42)
                                    .background(RoundedRectangleShape(cornerRadius: 10).fill(theme.editorColors.blue.opacity(0.2)))
                            }.disabled(!workspace.canEdit)
                        }.padding(12).background(RoundedRectangleShape(cornerRadius: 12).fill(theme.editorColors.surfaceElevated))
                    }
                }
            }
        }.padding(20).foregroundColor(theme.editorColors.text).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
