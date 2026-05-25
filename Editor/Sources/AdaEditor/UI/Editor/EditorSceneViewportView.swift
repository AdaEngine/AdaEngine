@_spi(AdaEngine) import AdaEngine

struct EditorSceneViewportView: View {
    let document: EditorSceneDocument
    let inspectorViewModel: EditorInspectorSidebarViewModel
    let playModeState: EditorPlayModeState
    let onDocumentChanged: (EditorSceneDocument) -> Void

    @State private var runtimeWarnings: [String] = []
    @State private var displayMode: EditorSceneViewportDisplayMode = .twoD
    @State private var activeTool: EditorSceneViewportTool = .translate
    @State private var viewportModel = EditorSceneViewportModel()
    @Environment(\.theme) private var theme
    @Environment(\.viewProxy) private var viewProxy

    var body: some View {
        let _ = isPlayingThisDocument ? preparePlayModeViewport() : configureViewportModel()
        ZStack {
            theme.editorColors.background

            if let errorMessage = document.errorMessage {
                viewportMessage(title: "Unable to open scene", message: errorMessage)
            } else if isPlayingThisDocument {
                playViewport
            } else {
                editViewport
            }
        }
        .accessibilityIdentifier("AdaEditor.SceneViewport.\(document.title)")
        .onDisappear {
            viewportModel.disconnect()
            inspectorViewModel.clearSceneViewportActions(owner: viewportModel)
        }
    }

    private var isPlayingThisDocument: Bool {
        if case .playing(let sceneDocumentID, _) = playModeState {
            return sceneDocumentID == document.id
        }

        return false
    }

    private var editViewport: some View {
        SceneView(setup: { world in
            let result = EditorSceneFileLoader.load(content: document.content, into: world)
            if runtimeWarnings != result.warnings {
                runtimeWarnings = result.warnings
            }
            viewportModel.attachSceneWorld(world, loadResult: result)
        }, update: { _, deltaTime in
            if viewportModel.update(deltaTime: deltaTime) {
                redrawViewport()
            }
        }, input: { event, _ in
            let handled = viewportModel.handleInput(event)
            if handled {
                redrawViewport()
            }
            return handled
        }) { context in
            VStack(spacing: 0) {
                toolbar
                context.viewport
                    .overlay { viewportSceneOverlay }
                    .overlay(anchor: .bottomLeading) { statusBar }
                    .mask(RectangleShape())
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
        }
    }

    private var playViewport: some View {
        SceneView(setup: { world in
            let result = EditorSceneFileLoader.load(content: document.content, into: world)
            if runtimeWarnings != result.warnings {
                runtimeWarnings = result.warnings
            }
        }) { context in
            VStack(spacing: 0) {
                playToolbar
                context.viewport
                    .overlay(anchor: .bottomLeading) { playStatusBar }
                    .mask(RectangleShape())
                    .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
            }
        }
    }

    private var viewportSceneOverlay: some View {
        ZStack {
            viewportGridLayer
            viewportGizmoLayer
        }
        .allowsHitTesting(false)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Text(document.title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text(document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
            viewportModeButton(.twoD)
            viewportModeButton(.threeD)
            toolbarDivider
            ForEach(EditorSceneViewportTool.allCases, id: \.rawValue) { tool in
                toolButton(tool)
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    private var playToolbar: some View {
        HStack(spacing: 8) {
            Text(document.title)
                .font(.system(size: 12))
                .foregroundColor(theme.editorColors.text)
            Text(document.relativePath)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
            adaEditorToolbarPill("Playing", active: true, theme: theme)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    private var toolbarDivider: some View {
        RectangleShape()
            .fill(theme.editorColors.border.opacity(0.8))
            .frame(width: 1, height: 18)
    }

    private var viewportGridLayer: some View {
        GeometryReader { proxy in
            let _ = viewportModel.setViewportSize(proxy.size)
            Canvas { context, size in
                let clipPath = RectangleShape().path(in: Rect(origin: .zero, size: size))
                context.clip(to: clipPath) { clippedContext in
                    viewportModel.drawGrid(in: &clippedContext, size: size, theme: theme)
                }
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var viewportGizmoLayer: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                let clipPath = RectangleShape().path(in: Rect(origin: .zero, size: size))
                context.clip(to: clipPath) { clippedContext in
                    viewportModel.drawGizmos(in: &clippedContext, size: size, theme: theme)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var statusBar: some View {
        HStack(spacing: 8) {
            Text(statusText)
                .font(.system(size: 11))
                .foregroundColor(statusColor)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface.opacity(0.88)))
            Spacer()
        }
        .padding(12)
    }

    private var playStatusBar: some View {
        HStack(spacing: 8) {
            Text(playStatusText)
                .font(.system(size: 11))
                .foregroundColor(playStatusColor)
                .padding(.horizontal, 10)
                .frame(height: 26)
                .background(RoundedRectangleShape(cornerRadius: 6).fill(theme.editorColors.surface.opacity(0.88)))
            Spacer()
        }
        .padding(12)
    }

    private var statusText: String {
        let warnings = document.loadSummary.warnings + runtimeWarnings
        if let firstWarning = warnings.first {
            return "Scene warning: \(firstWarning)"
        }

        return "Loaded \(document.loadSummary.entityCount) entities · \(viewportModel.statusSuffix)"
    }

    private var playStatusText: String {
        let warnings = document.loadSummary.warnings + runtimeWarnings
        if let firstWarning = warnings.first {
            return "Play warning: \(firstWarning)"
        }

        return "Playing \(document.loadSummary.entityCount) entities"
    }

    private var statusColor: Color {
        (document.loadSummary.warnings + runtimeWarnings).isEmpty ? theme.editorColors.muted : theme.editorColors.purple
    }

    private var playStatusColor: Color {
        (document.loadSummary.warnings + runtimeWarnings).isEmpty ? theme.editorColors.muted : theme.editorColors.purple
    }

    private func viewportModeButton(_ mode: EditorSceneViewportDisplayMode) -> some View {
        Button(action: { selectViewportMode(mode) }) {
            viewportModeButton(mode.rawValue, active: displayMode == mode)
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func viewportModeButton(_ title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: 10))
            .foregroundColor(active ? theme.editorColors.text : theme.editorColors.muted)
            .padding(.horizontal, 8)
            .frame(height: 22)
            .background(RoundedRectangleShape(cornerRadius: 5).fill(active ? theme.editorColors.blue.opacity(0.20) : theme.editorColors.surfaceElevated))
    }

    private func toolButton(_ tool: EditorSceneViewportTool) -> some View {
        Button(action: { selectTool(tool) }) {
            viewportModeButton(tool.rawValue, active: activeTool == tool)
        }
        .buttonStyle(DefaultButtonStyle())
    }

    private func selectViewportMode(_ mode: EditorSceneViewportDisplayMode) {
        displayMode = mode
        viewportModel.setDisplayMode(mode)
        redrawViewport()
    }

    private func selectTool(_ tool: EditorSceneViewportTool) {
        activeTool = tool
        viewportModel.setActiveTool(tool)
        redrawViewport()
    }

    private func configureViewportModel() {
        let viewportModel = viewportModel
        let inspectorViewModel = inspectorViewModel
        let document = document
        let onDocumentChanged = onDocumentChanged
        let viewProxy = viewProxy

        let loadResult = viewportModel.configure(
            sceneContent: document.content,
            onSelectionChanged: { [weak inspectorViewModel] selection in
                inspectorViewModel?.selectEntity(selection)
            },
            onDocumentContentChanged: { content in
                var updatedDocument = document
                updatedDocument.content = content
                updatedDocument.sceneModel = EditorSceneFileLoader.model(from: content)
                updatedDocument.isDirty = true
                updatedDocument.statusMessage = "Edited"
                updatedDocument.errorMessage = nil
                updatedDocument.loadSummary = EditorSceneFileLoader.summary(from: content)
                onDocumentChanged(updatedDocument)
            }
        )
        if let loadResult, runtimeWarnings != loadResult.warnings {
            runtimeWarnings = loadResult.warnings
            viewProxy.redraw()
        }
        inspectorViewModel.setSceneViewportActions(
            owner: viewportModel,
            applyGizmoChange: { [weak viewportModel] gizmo in
                guard let viewportModel else {
                    return
                }
                viewportModel.updateSelectedGizmo(gizmo)
                viewProxy.redraw()
            },
            addEntity: {
                Self.mutateSceneDocument(document: document, status: "Entity added", onDocumentChanged: onDocumentChanged) { model in
                    _ = model.addEntity()
                }
            },
            addComponent: { typeName in
                Self.mutateSceneDocument(document: document, status: "Component added", onDocumentChanged: onDocumentChanged) { model in
                    guard let selectedEntityID = model.editor?.selectedEntity else {
                        return
                    }
                    model.addComponent(typeName: typeName, to: selectedEntityID)
                }
            },
            removeComponent: { typeName in
                Self.mutateSceneDocument(document: document, status: "Component removed", onDocumentChanged: onDocumentChanged) { model in
                    guard let selectedEntityID = model.editor?.selectedEntity else {
                        return
                    }
                    model.removeComponent(typeName: typeName, from: selectedEntityID)
                }
            },
            updateComponentField: { typeName, field, value in
                Self.mutateSceneDocument(document: document, status: "Edited", onDocumentChanged: onDocumentChanged) { model in
                    guard let selectedEntityID = model.editor?.selectedEntity else {
                        return
                    }
                    model.updateField(typeName: typeName, field: field, value: value, in: selectedEntityID)
                }
            }
        )
    }

    private func preparePlayModeViewport() {
        viewportModel.disconnect()
        inspectorViewModel.clearSceneViewportActions(owner: viewportModel)
    }

    private func redrawViewport() {
        viewProxy.redraw()
    }

    private func mutateSceneDocument(status: String, update: (inout EditorSceneModel) -> Void) {
        Self.mutateSceneDocument(document: document, status: status, onDocumentChanged: onDocumentChanged, update: update)
    }

    private static func mutateSceneDocument(
        document: EditorSceneDocument,
        status: String,
        onDocumentChanged: (EditorSceneDocument) -> Void,
        update: (inout EditorSceneModel) -> Void
    ) {
        guard var model = document.sceneModel ?? EditorSceneFileLoader.model(from: document.content) else {
            return
        }

        update(&model)
        guard let content = try? model.encodedYAML() else {
            return
        }

        var updatedDocument = document
        updatedDocument.sceneModel = model
        updatedDocument.content = content
        updatedDocument.isDirty = true
        updatedDocument.statusMessage = status
        updatedDocument.errorMessage = nil
        updatedDocument.loadSummary = EditorSceneFileLoader.summary(from: content)
        onDocumentChanged(updatedDocument)
    }

    private func viewportMessage(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(theme.editorColors.text)
            Text(message)
                .font(.system(size: 11))
                .foregroundColor(theme.editorColors.muted)
            Spacer()
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
