@_spi(AdaEngine) import AdaEngine
import Foundation

struct EditorSceneViewportView: View {
    let document: EditorSceneDocument
    let resourceRootURL: URL?
    var uiCatalog: UICatalog = .standard
    let inspectorViewModel: EditorInspectorSidebarViewModel
    let playModeState: EditorPlayModeState
    let playRuntime: EditorScenePlayRuntime?
    let onEntitySelected: (() -> Void)?
    let onPlay: (() -> Void)?
    let onStop: (() -> Void)?
    let onDocumentChanged: (EditorSceneDocument) -> Void

    @State var runtimeWarnings: [String] = []
    @State private var displayMode: EditorSceneViewportDisplayMode = .twoD
    @State private var activeTool: EditorSceneViewportTool = .translate
    @State var viewportModel = EditorSceneViewportModel()
    @Environment(\.theme) var theme
    @Environment(\.viewProxy) var viewProxy

    var body: some View {
        let _ = isPlayingThisDocument ? preparePlayModeViewport() : configureViewportModel()
        ZStack {
            theme.editorColors.surfaceElevated

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
        VStack(spacing: 0) {
            toolbar
            GeometryReader { geometry in
                ZStack(anchor: .bottomLeading) {
                    SceneView(make: { app in
                        configureSceneViewApp(&app)
                        let result = EditorSceneFileLoader.load(
                            content: document.content,
                            into: app.main,
                            loadsScriptableObjects: false,
                            sourceURL: document.absolutePath.map { URL(fileURLWithPath: $0) },
                            resourceRootURL: resourceRootURL
                        )
                        if runtimeWarnings != result.warnings {
                            runtimeWarnings = result.warnings
                        }
                        viewportModel.attachSceneWorld(app.main, loadResult: result)
                    }, updateContent: { world, deltaTime in
                        if let input = world.getResource(Input.self) {
                            for event in input.getInputEvents() {
                                let handled = viewportModel.handleInput(event)
                                if handled {
                                    redrawViewport()
                                }
                            }
                        }
                        if viewportModel.update(deltaTime: deltaTime) {
                            redrawViewport()
                        }
                    })
                    .frame(width: geometry.size.width, height: geometry.size.height)

                    viewportSceneOverlay
                        .frame(width: geometry.size.width, height: geometry.size.height)

                    sceneControls(size: geometry.size)
                    statusBar
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .mask(RectangleShape())
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
    }

    private var playViewport: some View {
        VStack(spacing: 0) {
            playToolbar
            GeometryReader { geometry in
                ZStack(anchor: .bottomLeading) {
                    SceneView(make: { app in
                        configureSceneViewApp(&app)
                        do {
                            try playRuntime?.install(in: &app)
                        } catch {
                            runtimeWarnings = [error.localizedDescription]
                        }
                        let result = EditorSceneFileLoader.load(
                            content: document.content,
                            into: app.main,
                            sourceURL: document.absolutePath.map { URL(fileURLWithPath: $0) },
                            resourceRootURL: resourceRootURL
                        )
                        if runtimeWarnings != result.warnings {
                            runtimeWarnings = result.warnings
                        }
                    }, updateContent: { _, _ in })
                    .frame(width: geometry.size.width, height: geometry.size.height)

                    sceneControls(size: geometry.size)
                    playStatusBar
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
                .mask(RectangleShape())
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        }
    }

    @MainActor
    static func uiProjectRoot(from resourceRoot: URL) -> URL {
        var candidate = resourceRoot
        while candidate.path != "/" {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent(".ada/project.json").path)
                || FileManager.default.fileExists(atPath: candidate.appendingPathComponent("Package.swift").path) { return candidate }
            candidate.deleteLastPathComponent()
        }
        return resourceRoot
    }

    private func configureSceneViewApp(_ app: inout AppWorlds) {
        if let resourceRootURL {
            let runtime = UIComponentRuntime(resourceRoot: resourceRootURL, catalog: uiCatalog)
            runtime.enableAdaScript(sourceRoot: Self.uiProjectRoot(from: resourceRootURL))
            app.main.insertResource(UIComponentRuntimeResource(runtime))
        }

        EditorComponentRegistry.registerBuiltIns()
        app.addPlugin(TransformPlugin())
        app.addPlugin(InputPlugin())
        app.addPlugin(RenderWorldPlugin())
        app.addPlugin(EventsPlugin())
        app.addPlugin(CameraPlugin())
        app.addPlugin(AssetsPlugin(filePath: #filePath))
        app.addPlugin(VisibilityPlugin())
        app.addPlugin(SpritePlugin())
        app.addPlugin(Mesh2DPlugin())
        app.addPlugin(TextPlugin())
        app.addPlugin(ScenePlugin())
        if isPlayingThisDocument {
            app.addPlugin(ScriptableObjectPlugin())
        }
        app.addPlugin(Physics2DPlugin())
        app.addPlugin(TileMapPlugin())
        app.addPlugin(Core2DPlugin())
        app.addPlugin(Core3DPlugin())
        app.addPlugin(Light2DPlugin())
        app.addPlugin(UpscalePlugin())
    }

    private var viewportSceneOverlay: some View {
        ZStack(anchor: .topLeading) {
            viewportGridLayer
            viewportGizmoLayer
            viewportCoordinateRulerLayer
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
            Text(isPlayingThisDocument ? "PLAY MODE" : "SCENE")
                .font(.system(size: 10))
                .foregroundColor(isPlayingThisDocument ? theme.editorColors.purple : theme.editorColors.muted)
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
            Text("PLAY MODE")
                .font(.system(size: 10))
                .foregroundColor(theme.editorColors.purple)
        }
        .padding(.horizontal, 12)
        .frame(height: 34)
        .background(theme.editorColors.surface)
    }

    private func sceneControls(size: Size) -> some View {
        EditorSceneViewportControls(
            activeTool: activeTool,
            displayMode: displayMode,
            isPlaying: isPlayingThisDocument,
            size: size,
            onCreate: { preset in
                inspectorViewModel.addEntityRequested(preset)
                onEntitySelected?()
                redrawViewport()
            },
            onPlay: { onPlay?() },
            onSelectDisplayMode: selectViewportMode,
            onSelectTool: selectTool,
            onStop: { onStop?() }
        )
    }

    private var viewportGridLayer: some View {
        GeometryReader { proxy in
            let _ = viewportModel.setViewportSize(proxy.size)
            Canvas { context, size in
                viewportModel.drawGrid(in: &context, size: size, theme: theme)
            }
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }

    private var viewportGizmoLayer: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                viewportModel.drawGizmos(in: &context, size: size, theme: theme)
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
