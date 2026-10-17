#if os(visionOS)
    import SwiftUI

    /// Native chrome delegates every action to the same AdaUI Studio/workbench models.
    @available(visionOS 26.0, *)
    struct EditorVRStudioOrnaments: SwiftUI.ViewModifier {
        let workspace: EditorVRWorkspace
        let visible: Bool
        let resize: () -> Void
        let enter: ((EditorVRImmersionMode) -> Void)?
        private var visibility: SwiftUI.Visibility { visible && workspace.studio != nil ? .visible : .hidden }

        private var editorVisibility: SwiftUI.Visibility {
            visible && workspace.studio?.interface.mode == .editor ? .visible : .hidden
        }

        func body(content: Content) -> some SwiftUI.View {
            content
                .ornament(visibility: visibility, attachmentAnchor: .scene(.bottom), contentAlignment: .top) {
                    EditorVRWindowActions(workspace: workspace, resize: resize, enter: enter).padding(.top, 16)
                }
                .ornament(visibility: editorVisibility, attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
                    if let editor = workspace.studio {
                        EditorVRPanelTabs(editor: editor, workspace: workspace, side: .leading).padding(.trailing, 14)
                    }
                }
                .ornament(visibility: editorVisibility, attachmentAnchor: .scene(.trailing), contentAlignment: .leading) {
                    if let editor = workspace.studio {
                        EditorVRPanelTabs(editor: editor, workspace: workspace, side: .trailing).padding(.leading, 14)
                    }
                }
                .ornament(visibility: editorVisibility, attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
                    if let editor = workspace.studio {
                        EditorVRDocumentTabs(editor: editor).padding(.bottom, 16)
                    }
                }
        }
    }

    private struct EditorVRWindowActions: SwiftUI.View {
        @SwiftUI.Environment(\.openWindow) private var openWindow
        let workspace: EditorVRWorkspace
        let resize: () -> Void
        let enter: ((EditorVRImmersionMode) -> Void)?

        var body: some SwiftUI.View {
            SwiftUI.HStack(spacing: 12) {
                SwiftUI.Button(action: resize) { SwiftUI.Label(L10n.text("Wide"), systemImage: "arrow.left.and.right") }
                    .accessibilityIdentifier("AdaEditor.VR.WideWindow")
                SwiftUI.Button {
                    openWindow(id: EditorVRPanel.voice.windowID, value: true)
                } label: {
                    SwiftUI.Label(L10n.text("Ada"), systemImage: "sparkles")
                }.accessibilityLabel(L10n.text("Open Ada bubble")).accessibilityIdentifier("AdaEditor.VR.OpenVoiceBubble")
                if let enter {
                    SwiftUI.Divider().frame(height: 24)
                    SwiftUI.Button { enter(.full) } label: {
                        SwiftUI.Label(workspace.isOpening ? L10n.text("Entering…") : L10n.text("Enter Immersive"), systemImage: "visionpro")
                    }
                    .disabled(workspace.document == nil || workspace.isOpening)
                    .accessibilityIdentifier("AdaEditor.VR.Enter")
                    SwiftUI.Button { enter(.mixed) } label: {
                        SwiftUI.Label(L10n.text("Mixed"), systemImage: "person.crop.rectangle")
                    }
                    .disabled(workspace.document == nil || workspace.isOpening)
                    .accessibilityIdentifier("AdaEditor.VR.EnterMixed")
                }
            }.buttonStyle(.borderless).controlSize(.large).padding(12)
                .glassBackgroundEffect(in: SwiftUI.Capsule())
        }
    }

    private struct EditorVRPanelTabs: SwiftUI.View {
        let editor: EditorViewModel
        let workspace: EditorVRWorkspace
        let side: SwiftUI.HorizontalAlignment

        var body: some SwiftUI.View {
            SwiftUI.VStack(spacing: 4) {
                if side == .leading {
                    ForEach(editor.toolStrip.leftTopTools, id: \.identifier) { item in
                        tool(item, selected: editor.isLeftTopToolPresented(item)) { editor.activateLeftTopTool(item) }
                    }
                    SwiftUI.Divider().frame(width: 32).padding(.vertical, 6)
                    ForEach(editor.toolStrip.leftBottomTools, id: \.identifier) { item in
                        tool(item, selected: editor.isLeftBottomToolPresented(item)) { editor.activateLeftBottomTool(item) }
                    }
                } else {
                    ForEach(editor.toolStrip.rightTools, id: \.identifier) { item in
                        tool(item, selected: item.identifier == "projectSettings" ? workspace.presentedPanels.contains(.settings) : editor.isRightToolPresented(item)) {
                            editor.activateRightTool(item)
                        }
                    }
                }
            }.padding(8).glassBackgroundEffect(in: SwiftUI.RoundedRectangle(cornerRadius: 28))
        }

        private func tool(_ item: EditorToolStripItem, selected: Bool, action: @escaping () -> Void) -> some SwiftUI.View {
            SwiftUI.Button(action: action) {
                SwiftUI.Image(systemName: symbol(item.identifier)).font(.title3).frame(width: 44, height: 44)
                    .background(selected ? SwiftUI.Color.accentColor.opacity(0.28) : .clear, in: SwiftUI.RoundedRectangle(cornerRadius: 14))
            }.buttonStyle(.plain).padding(4).hoverEffect(.highlight)
                .help(item.title).accessibilityLabel(item.title)
                .accessibilityIdentifier("AdaEditor.ToolStrip.\(item.identifier)")
        }

        private func symbol(_ id: String) -> String {
            switch id {
            case "fileTree": "folder"
            case "sourceControl": "point.3.connected.trianglepath.dotted"
            case "logs": "terminal"
            case "build": "hammer"
            case "debug": "ladybug"
            case "animator": "film.stack"
            case "agentChat": "sparkles"
            case "inspector": "info.circle"
            case "projectDependencies": "shippingbox"
            case "swiftPackageTasks": "cube"
            case "plugins": "puzzlepiece.extension"
            case "projectSettings": "gearshape"
            default: "square.grid.2x2"
            }
        }
    }

    private struct EditorVRDocumentTabs: SwiftUI.View {
        let editor: EditorViewModel
        private var workbench: EditorWorkbenchViewModel { editor.workbench }

        var body: some SwiftUI.View {
            SwiftUI.VStack(spacing: 8) {
                row(.primary)
                if workbench.isSplit { row(.secondary) }
            }.padding(10).glassBackgroundEffect(in: SwiftUI.RoundedRectangle(cornerRadius: 24))
        }

        private func row(_ pane: EditorWorkbenchPane) -> some SwiftUI.View {
            SwiftUI.HStack(spacing: 8) {
                if workbench.isSplit {
                    SwiftUI.Button(pane == .primary ? L10n.text("Left") : L10n.text("Right")) { workbench.focusPane(pane) }
                        .tint(workbench.focusedPane == pane ? .accentColor : .secondary)
                }
                SwiftUI.Button {
                    workbench.filesBrowserPanes.insert(pane)
                } label: {
                    SwiftUI.Label(L10n.text("Files"), systemImage: "folder")
                }.tint(workbench.filesBrowserPanes.contains(pane) ? .accentColor : .secondary)
                    .accessibilityIdentifier(pane == .primary ? "AdaEditor.Tab.Files" : "AdaEditor.Tab.Files.secondary")
                SwiftUI.ScrollView(.horizontal, showsIndicators: false) {
                    SwiftUI.HStack(spacing: 6) {
                        ForEach(workbench.documents(in: pane), id: \.id) { document in tab(document) }
                    }
                }.frame(width: 640, height: 48)
                if workbench.isSplit {
                    SwiftUI.Button(L10n.text("Merge")) { workbench.mergePanes() }
                } else if let document = workbench.selectedDocument(in: pane) {
                    SwiftUI.Button(L10n.text("Split")) { workbench.splitDocument(id: document.id) }
                }
            }.buttonStyle(.borderless)
        }

        private func tab(_ document: EditorWorkbenchDocument) -> some SwiftUI.View {
            SwiftUI.HStack(spacing: 6) {
                SwiftUI.Button {
                    workbench.filesBrowserPanes.remove(workbench.pane(for: document.id))
                    editor.selectWorkbenchDocument(id: document.id)
                } label: {
                    SwiftUI.HStack(spacing: 6) {
                        SwiftUI.Image(systemName: isScene(document) ? "cube" : "doc.text")
                        SwiftUI.Text(document.title).lineLimit(1)
                        if document.isDirty { SwiftUI.Circle().frame(width: 6, height: 6) }
                    }
                }.accessibilityIdentifier("AdaEditor.Tab.Select.\(document.id)")
                SwiftUI.Button {
                    workbench.closeDocument(id: document.id)
                } label: {
                    SwiftUI.Image(systemName: "xmark").font(.caption)
                }
                .accessibilityLabel(L10n.text("Close \(document.title)")).accessibilityIdentifier("AdaEditor.Tab.Close.\(document.id)")
            }.padding(.horizontal, 12).padding(.vertical, 10)
                .background(
                    !workbench.filesBrowserPanes.contains(workbench.pane(for: document.id)) && workbench.selectedDocument(in: workbench.pane(for: document.id))?.id == document.id
                        ? SwiftUI.Color.accentColor.opacity(0.22) : .clear,
                    in: SwiftUI.RoundedRectangle(cornerRadius: 12)
                )
                .draggable(document.id)
                .dropDestination(for: String.self) { values, _ in
                    guard let id = values.first, id != document.id, workbench.openDocuments.contains(where: { $0.id == id }),
                        let index = workbench.openDocuments.firstIndex(where: { $0.id == document.id })
                    else { return false }
                    workbench.moveDocument(id: id, to: workbench.pane(for: document.id))
                    workbench.moveDocument(id: id, toIndex: index)
                    return true
                }
                .contextMenu {
                    SwiftUI.Button(workbench.pane(for: document.id) == .secondary ? L10n.text("Move to Left Group") : L10n.text("Split Right")) {
                        if workbench.pane(for: document.id) == .secondary { workbench.moveDocument(id: document.id, to: .primary) } else { workbench.splitDocument(id: document.id) }
                    }
                    SwiftUI.Button(L10n.text("Close Others")) { workbench.closeOtherDocuments(keeping: document.id) }
                    SwiftUI.Button(L10n.text("Close Left")) { workbench.closeDocumentsToLeft(of: document.id) }
                    SwiftUI.Button(L10n.text("Close Right")) { workbench.closeDocumentsToRight(of: document.id) }
                    SwiftUI.Button(L10n.text("Close Clean")) { workbench.closeCleanDocuments() }
                    SwiftUI.Button(L10n.text("Close All")) { workbench.closeAllDocuments() }
                    if document.absolutePath != nil {
                        SwiftUI.Button(L10n.text("Reveal File")) { editor.revealDocument(document) }
                        SwiftUI.Button(L10n.text("Copy Relative Path")) { editor.copyDocumentPath(document, relative: true) }
                        SwiftUI.Button(L10n.text("Copy Absolute Path")) { editor.copyDocumentPath(document, relative: false) }
                    }
                }
        }

        private func isScene(_ document: EditorWorkbenchDocument) -> Bool {
            if case .scene = document {
                return true
            }
            return false
        }
    }
#endif
