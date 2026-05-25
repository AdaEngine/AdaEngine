//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

@_spi(AdaEngine) import AdaEngine

enum AdaEngineStyleContent {
    static let topToolbarLabels = ["Search Everywhere", "main_scene", "Hot Reload", "Run"]
    static let leftTopSidebarTools = [
        EditorToolStripItem(identifier: "fileTree", title: "File Tree", icon: "\u{E2C7}"),
        EditorToolStripItem(identifier: "entityTree", title: "Entity Tree", icon: "\u{E97A}"),
        EditorToolStripItem(identifier: "sourceControl", title: "Source Control", icon: "\u{F1C4}"),
        EditorToolStripItem(identifier: "tests", title: "Tests", icon: "\u{E86C}")
    ]
    static let leftBottomSidebarTools = [
        EditorToolStripItem(identifier: "logs", title: "Logs", icon: "\u{EB8E}"),
        EditorToolStripItem(identifier: "build", title: "Build", icon: "\u{E869}"),
        EditorToolStripItem(identifier: "animator", title: "Animator", icon: "\u{E71C}")
    ]
    static let rightSidebarTools = [
        EditorToolStripItem(identifier: "agentChat", title: "Agent Chat", icon: "\u{E0CA}"),
        EditorToolStripItem(identifier: "inspector", title: "Inspector", icon: "\u{E88E}"),
        EditorToolStripItem(identifier: "projectDependencies", title: "Project Dependencies", icon: "\u{E48F}"),
        EditorToolStripItem(identifier: "swiftPackageTasks", title: "Swift Package Tasks", icon: "\u{F720}"),
        EditorToolStripItem(identifier: "plugins", title: "Plugins", icon: "\u{E87B}"),
        EditorToolStripItem(identifier: "projectSettings", title: "Project Settings", icon: "\u{E8B8}")
    ]
    static let projectTreeItems = ["src", "EngineLoop.ada", "Renderer.ada", "Main.ascn"]
    static let editorTabs = ["EngineLoop.ada", "Main.ascn"]
    static let sampleTextDocuments = [
        "src/EngineLoop.ada": """
        import AdaEngine
        
        @system
        struct EngineLoop {
            let fixedDelta = 1.0 / 60.0
        
            func update(scene: Scene, deltaTime: Float) {
                // Game simulation entry point.
                scene.physics.step(deltaTime)
            }
        }
        """,
        "src/Renderer.ada": """
        render_pipeline MainRenderer {
            colorAttachment = .hdr
            depthTest = true
        
            pass geometry {
                shader = "Shaders/MainSurface.glsl"
            }
        }
        """
    ]
    static let defaultSceneModel = EditorSceneModel.default(projectName: "Main")
    static let defaultSceneContent = (try? defaultSceneModel.encodedYAML()) ?? SceneDocumentFormat.defaultSceneYAML(projectName: "Main")
    static let defaultEditorDocuments: [EditorWorkbenchDocument] = [
        .text(
            EditorTextDocument(
                id: "text:src/EngineLoop.ada",
                title: "EngineLoop.ada",
                relativePath: "src/EngineLoop.ada",
                language: .ada,
                content: sampleTextDocuments["src/EngineLoop.ada"] ?? "",
                errorMessage: nil
            )
        ),
        .scene(
            EditorSceneDocument(
                id: "scene:Assets/Scenes/Main.ascn",
                title: "Main.ascn",
                relativePath: "Assets/Scenes/Main.ascn",
                absolutePath: nil,
                content: defaultSceneContent,
                sceneModel: defaultSceneModel,
                errorMessage: nil,
                isDirty: false,
                statusMessage: "Sample scene",
                loadSummary: EditorSceneFileLoader.summary(from: defaultSceneContent)
            )
        )
    ]
    static let aiTitle = "Ada Intelligence"
    static let aiHint = "⌘L to Focus"
    static let aiPlaceholder = "Ask to generate logic, optimize shaders, or place objects..."
    static let aiChips = ["Refactor current scene", "Optimize render batches", "Auto-light"]
    static let inspectorScript = "DynamicBouncer.ada"
    static let inspectorScriptDescription = "Object bounces on contact"
    static let outputTabs = ["Problems", "Build", "Tests", "References", "Output"]
    static let logLines = [
        "[12:04:11] Ada Engine initialized — render backend ready.",
        "[12:04:12] Loaded Main.ascn with 1 entity.",
        "[12:04:14] AI optimization note: draw calls can be batched by material.",
        "[12:04:16] Build completed with 0 problems."
    ]
    static let footerLeft = ["Built in 142ms", "Renderer Ready"]
    static let footerRight = ["3:12 LF UTF-8", "Git: main*"]
}

struct EditorView: View {
    let project: EditorProjectReference?
    let hotReloadState: EditorHotReloadState
    @State private var viewModel: EditorViewModel
    @Environment(\.theme) private var theme
    
    init(project: EditorProjectReference?, hotReloadState: EditorHotReloadState) {
        self.project = project
        self.hotReloadState = hotReloadState
        self._viewModel = State(initialValue: EditorViewModel(project: project))
    }
    
    var body: some View {
        GeometryReader { geometry in
            let metrics = AdaEngineStyleLayoutMetrics(size: geometry.size)
            VStack(spacing: metrics.workspaceSpacer) {
                EditorTopToolbarRegion(
                    hotReloadState: hotReloadState,
                    viewModel: viewModel
                )
                .onAppear {
                    viewModel.startEditorSessionIfNeeded()
                }
                .frame(height: metrics.topToolbarHeight)
                
                EditorWorkspaceRegion(viewModel: viewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                EditorFooterRegion(
                    hotReloadState: hotReloadState,
                    viewModel: viewModel
                )
                .frame(height: metrics.footerHeight)
            }
            .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
            .foregroundColor(theme.editorColors.text)
            .environment(\.metrics, metrics)
        }
        .padding(.all, 4)
        .background {
            theme.editorColors.background
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .keyboardShortcuts(editorKeyboardShortcuts)
        .debugOverlay(viewModel.showsDebugOverlay ?? .off)
    }

    private var editorKeyboardShortcuts: [KeyboardShortcutAction] {
        [
            KeyboardShortcutAction(.r, modifiers: .command) {
                viewModel.toggleDebugOverlay(.redraw)
            },
            KeyboardShortcutAction(.d, modifiers: .command) {
                viewModel.toggleDebugOverlay(.layoutBounds)
            },
            KeyboardShortcutAction(.s, modifiers: .command) {
                viewModel.saveActiveDocument()
            },
            KeyboardShortcutAction(.plus, modifiers: .command) {
                viewModel.workbench.increaseCodeFontSize()
            },
            KeyboardShortcutAction(.equals, modifiers: .command) {
                viewModel.workbench.increaseCodeFontSize()
            },
            KeyboardShortcutAction(.minus, modifiers: .command) {
                viewModel.workbench.decreaseCodeFontSize()
            },
            KeyboardShortcutAction(.num0, modifiers: .command) {
                viewModel.workbench.resetCodeFontSize()
            },
            KeyboardShortcutAction(.plus, modifiers: .control) {
                viewModel.workbench.increaseCodeFontSize()
            },
            KeyboardShortcutAction(.equals, modifiers: .control) {
                viewModel.workbench.increaseCodeFontSize()
            },
            KeyboardShortcutAction(.minus, modifiers: .control) {
                viewModel.workbench.decreaseCodeFontSize()
            },
            KeyboardShortcutAction(.num0, modifiers: .control) {
                viewModel.workbench.resetCodeFontSize()
            }
        ]
    }
}

private struct EditorTopToolbarRegion: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorViewModel
    
    var body: some View {
        EditorTopToolbar(
            hotReloadState: hotReloadState,
            viewModel: viewModel.toolbar,
            isRunEnabled: !viewModel.playModeState.isPlaying,
            isStopEnabled: viewModel.playModeState.isPlaying,
            onRun: {
                viewModel.runActiveSceneInEditor()
            },
            onStop: {
                viewModel.stopPlayMode()
            }
        )
    }
}

private struct EditorWorkspaceRegion: View {
    let viewModel: EditorViewModel
    @Environment(\.metrics) private var metrics
    
    var body: some View {
        HStack(spacing: 0) {
            EditorLeftToolStrip(
                viewModel: viewModel,
                onSelectTopTool: { item in
                    viewModel.activateLeftTopTool(item)
                },
                onSelectBottomTool: { item in
                    viewModel.activateLeftBottomTool(item)
                }
            )
            .frame(minWidth: metrics.toolStripWidth, maxWidth: metrics.toolStripWidth, maxHeight: .infinity)
            
            EditorWorkspaceView(
                viewModel: viewModel,
                leftPanel: {
                    EditorLeftSidebarContent(viewModel: viewModel)
                },
                mainPanel: {
                    EditorCenterWorkbench(
                        viewModel: viewModel.workbench,
                        inspectorViewModel: viewModel.inspectorSidebar,
                        playModeState: viewModel.playModeState,
                        onSourceHover: { document, position in
                            viewModel.handleSourceHover(document: document, position: position)
                        },
                        onGoToDefinition: { document, position in
                            viewModel.goToDefinition(document: document, position: position)
                        },
                        sourceContextMenuItems: { document, position in
                            viewModel.sourceContextMenuItems(document: document, position: position)
                        },
                        onSelectDocument: { documentID in
                            viewModel.selectWorkbenchDocument(id: documentID)
                        },
                        onSelectPreview: { declaration in
                            viewModel.selectPreview(declaration)
                        },
                        onRebuildPreview: {
                            viewModel.rebuildSelectedPreview()
                        },
                        onShowPreviewBuildOutput: {
                            viewModel.showBuildOutput()
                        }
                    )
                        .frame(maxHeight: .infinity)
                },
                rightPanel: {
                    EditorRightSidebarContent(viewModel: viewModel)
                },
                bottomPanel: {
                    EditorBottomPanel(viewModel: viewModel)
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .layoutPriority(2)
            
            EditorRightToolStrip(
                viewModel: viewModel,
                onSelectTool: { item in
                    viewModel.activateRightTool(item)
                }
            )
            .frame(minWidth: metrics.toolStripWidth, maxWidth: metrics.toolStripWidth, maxHeight: .infinity)
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity, alignment: .topLeading)
    }
}

private struct EditorLeftSidebarContent: View {
    let viewModel: EditorViewModel

    var body: some View {
        if viewModel.toolStrip.activeLeftTopTool == "entityTree" {
            EditorSceneHierarchySidebar(
                document: viewModel.workbench.activeSceneDocument,
                onSelectEntity: { entityID in
                    guard let documentID = viewModel.workbench.activeSceneDocument?.id else {
                        return
                    }
                    viewModel.workbench.selectSceneEntity(documentID: documentID, entityID: entityID)
                },
                onToggleEntityExpanded: { entityID in
                    guard let documentID = viewModel.workbench.activeSceneDocument?.id else {
                        return
                    }
                    viewModel.workbench.toggleSceneEntityExpanded(documentID: documentID, entityID: entityID)
                }
            )
        } else if viewModel.toolStrip.activeLeftTopTool == "sourceControl" {
            EditorSourceControlSidebar(viewModel: viewModel)
        } else {
            EditorProjectSidebar(
                viewModel: viewModel.projectSidebar,
                onOpenItem: { item in
                    viewModel.openProjectItem(item)
                },
                onOpenRawItem: { item in
                    viewModel.openProjectItemAsRaw(item)
                },
                onImportAssets: {
                    viewModel.importAssets()
                }
            )
        }
    }
}

private struct EditorRightSidebarContent: View {
    let viewModel: EditorViewModel
    
    var body: some View {
        if viewModel.toolStrip.activeRightTool == "agentChat" {
            EditorAgentSidebar(viewModel: viewModel.agent)
        } else if viewModel.toolStrip.activeRightTool == "inspector" {
            EditorInspectorSidebar(viewModel: viewModel.inspectorSidebar)
        } else {
            EditorProjectToolSidebar(viewModel: viewModel)
        }
    }
}

private struct EditorFooterRegion: View {
    let hotReloadState: EditorHotReloadState
    let viewModel: EditorViewModel
    
    var body: some View {
        EditorFooter(
            hotReloadState: hotReloadState,
            viewModel: viewModel.footer
        )
    }
}

struct EditorResizeHandle: View {
    enum Axis {
        case horizontal
        case vertical
    }
    
    let axis: Axis
    let onResize: (Size) -> Void
    let onResizeEnded: () -> Void
    
    init(axis: Axis, onResize: @escaping (Size) -> Void = { _ in }, onResizeEnded: @escaping () -> Void = {}) {
        self.axis = axis
        self.onResize = onResize
        self.onResizeEnded = onResizeEnded
    }
    
    @ViewBuilder
    var body: some View {
        switch axis {
        case .horizontal:
            hitArea
                .frame(width: 8)
                .frame(maxHeight: .infinity)
        case .vertical:
            hitArea
                .frame(height: 8)
                .frame(maxWidth: .infinity)
        }
    }
    
    private var hitArea: some View {
        RectangleShape()
            .fill(Color.clear)
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        onResize(value.translation)
                    }
                    .onEnded { _ in
                        onResizeEnded()
                    }
            )
            .cursorShape(cursorShape)
    }
    
    private var cursorShape: Input.CursorShape {
        switch axis {
        case .horizontal:
            return .resizeLeftRight
        case .vertical:
            return .resizeUpDown
        }
    }
}

private extension Glass {
    static func editorWindowBackground(theme: Theme) -> Glass {
        var glass = Glass.regular
        glass.blurRadius = 24
        glass.glassTintStrength = 0.72
        glass.edgeShadowStrength = 0
        glass.tintColor = theme.editorColors.background.opacity(0.18)
        return glass
    }
}
