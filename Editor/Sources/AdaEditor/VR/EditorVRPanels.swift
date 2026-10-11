import AdaEngine
import Foundation

struct EditorVRDock: View {
    let workspace: EditorVRWorkspace
    let togglePanel: (EditorVRPanel) -> Void
    let focusSelection: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { togglePanel(.project) }) {
                    HStack(spacing: 8) {
                        Text("\u{E2C7}").font(AdaEditorMaterialSymbolFont.font(size: 18))
                        Text(workspace.project?.name ?? "Ada Studio VR").font(.system(size: 15, weight: .semibold)).lineLimit(1)
                        Text(workspace.document?.title ?? "").font(.system(size: 13)).foregroundColor(theme.editorColors.muted).lineLimit(1)
                        Text("\u{E5CF}").font(AdaEditorMaterialSymbolFont.font(size: 16))
                    }
                }.buttonStyle(DefaultButtonStyle()).accessibilityIdentifier("AdaEditor.VR.Project")
                Button("Studio") { togglePanel(.studio) }.accessibilityIdentifier("AdaEditor.VR.Panel.studio")
                Button("Files") { togglePanel(.files) }.accessibilityIdentifier("AdaEditor.VR.Panel.files")
                Button("Voice") { togglePanel(.voice) }.accessibilityIdentifier("AdaEditor.VR.Panel.voice")
                Spacer()
                if let name = workspace.selectedName {
                    Button(action: focusSelection) {
                        HStack(spacing: 6) {
                            Text("\u{E3A5}").font(AdaEditorMaterialSymbolFont.font(size: 17))
                            Text(name).font(.system(size: 14)).lineLimit(1)
                        }
                    }.disabled(workspace.isManipulating).accessibilityIdentifier("AdaEditor.VR.Focus")
                }
                CircleShape().fill(statusColor).frame(width: 7, height: 7)
                Text(workspace.saveStatus).font(.system(size: 13)).foregroundColor(statusColor)
                    .accessibilityIdentifier("AdaEditor.VR.SaveStatus")
                Button(action: { togglePanel(.navigation) }) {
                    Text("\u{E89F}").font(AdaEditorMaterialSymbolFont.font(size: 19)).frame(width: 32, height: 28)
                }.accessibilityIdentifier("AdaEditor.VR.Navigation")
            }.foregroundColor(theme.editorColors.text).padding(.horizontal, 8)

            HStack(spacing: 6) {
                panelButton(.assets, title: "Assets", symbol: "\u{E2C7}")
                panelButton(.hierarchy, title: "Scene", symbol: "\u{E8F0}")
                panelButton(.inspector, title: "Inspector", symbol: "\u{E8B8}")
                divider
                ForEach([EditorSceneViewportTool.select, .translate, .rotate, .scale], id: \.rawValue) { tool in
                    EditorVRDockButton(title: tool.rawValue, symbol: tool.vrSymbol, active: workspace.activeTool == tool) {
                        workspace.setTool(tool)
                    }
                    .disabled(workspace.isManipulating || workspace.document == nil || (tool != .select && !workspace.canEdit))
                    .accessibilityIdentifier("AdaEditor.VR.Tool.\(tool.rawValue)")
                }
                divider
                EditorVRDockButton(title: "Undo", symbol: "\u{E166}", action: workspace.undo)
                    .disabled(!workspace.canUndo).opacity(workspace.canUndo ? 1 : 0.4).accessibilityIdentifier("AdaEditor.VR.Undo")
                EditorVRDockButton(title: "Redo", symbol: "\u{E15A}", action: workspace.redo)
                    .disabled(!workspace.canRedo).opacity(workspace.canRedo ? 1 : 0.4).accessibilityIdentifier("AdaEditor.VR.Redo")
                EditorVRDockButton(title: "Save", symbol: "\u{E161}", action: workspace.save)
                    .disabled(!workspace.canSave).opacity(workspace.canSave ? 1 : 0.4).accessibilityIdentifier("AdaEditor.VR.Save")
            }
        }.padding(14).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var divider: some View { theme.editorColors.border.opacity(0.6).frame(width: 1, height: 38).padding(.horizontal, 4) }
    private var statusColor: Color {
        if workspace.saveFailure != nil {
            return Color.fromHex(0xFF7474)
        }
        return Color.fromHex(workspace.saveStatus == "Saved" ? 0x64D6AA : 0xD7BD81)
    }
    private func panelButton(_ panel: EditorVRPanel, title: String, symbol: String) -> some View {
        EditorVRDockButton(title: title, symbol: symbol, active: workspace.presentedPanels.contains(panel)) { togglePanel(panel) }
            .accessibilityIdentifier("AdaEditor.VR.Panel.\(panel.rawValue)")
    }
}

struct EditorVRDockButton: View {
    let title: String
    let symbol: String
    var active = false
    let action: () -> Void
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                Text(symbol).font(AdaEditorMaterialSymbolFont.font(size: 25))
                Text(title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
            }
            .foregroundColor(active ? Color.white : theme.editorColors.text)
            .frame(width: 62, height: 66)
            .background(RoundedRectangleShape(cornerRadius: 15).fill(active ? theme.editorColors.blue : Color.clear))
        }.buttonStyle(EditorVRButtonStyle())
    }
}

struct EditorVRButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(RoundedRectangleShape(cornerRadius: 15).fill(configuration.state.isHighlighted ? Color.white.opacity(0.12) : Color.clear))
    }
}

