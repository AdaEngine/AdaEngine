import AdaEngine

/// Existing Studio views and services, hosted by the same project/workbench.
struct EditorVRStudioPanel: View {
    let workspace: EditorVRWorkspace
    let panel: EditorVRPanel

    @ViewBuilder var body: some View {
        if let editor = workspace.studio {
            Group {
                switch panel {
                case .console:
                    EditorBottomPanel(viewModel: editor)
                case .agent:
                    EditorAgentSidebar(
                        viewModel: editor.agent,
                        onOpenCatalog: {
                            editor.presentSettings(.agent)
                            workspace.activatedPalmPanel = .settings
                        }
                    )
                case .settings:
                    if let settings = workspace.settingsWindow { EditorSettingsWindowView(viewModel: settings) }
                default:
                    EditorView(project: workspace.project, viewModel: editor, usesNativeOrnaments: true)
                }
            }.onAppear {
                editor.startEditorSessionIfNeeded()
                if panel == .files {
                    editor.showLeftPanel = true
                    editor.toolStrip.activeLeftTopTool = "fileTree"
                }
                if panel == .settings, workspace.settingsWindow == nil {
                    workspace.prepareSettingsWindow()
                }
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            .disabled(workspace.isManipulating)
        } else {
            Text(L10n.text("Open a project to use Studio panels.")).padding(24)
        }
    }
}
