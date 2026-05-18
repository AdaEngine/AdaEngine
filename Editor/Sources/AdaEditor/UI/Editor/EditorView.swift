//
//  EditorWindow.swift
//  AdaEngine
//
//  Created by v.prusakov on 5/31/22.
//

@_spi(AdaEngine) import AdaEngine

enum AdaEngineStyleContent {
    static let topToolbarLabels = ["Search Everywhere", "main_scene", "Hot Reload", "Run"]
    static let projectTreeItems = ["src", "EngineLoop.ada", "Renderer.ada"]
    static let editorTabs = ["EngineLoop.ada", "MainLevel.scene"]
    static let aiTitle = "Ada Intelligence"
    static let aiHint = "⌘L to Focus"
    static let aiPlaceholder = "Ask to generate logic, optimize shaders, or place objects..."
    static let aiChips = ["Refactor current scene", "Optimize Vulkan DrawCalls", "Auto-light"]
    static let inspectorScript = "DynamicBouncer.ada"
    static let inspectorScriptDescription = "Object bounces on contact"
    static let outputTabs = ["Problems", "Output", "Terminal", "Vulkan Profiler", "AI Chat History"]
    static let logLines = [
        "[12:04:11] Ada Engine initialized — Vulkan backend ready.",
        "[12:04:12] Loaded MainLevel.scene with 48 entities.",
        "[12:04:14] AI optimization note: Vulkan DrawCalls can be batched by material.",
        "[12:04:16] Build completed with 0 problems."
    ]
    static let footerLeft = ["Built in 142ms", "Vulkan Enabled"]
    static let footerRight = ["3:12 LF UTF-8", "Git: main*"]
}

struct EditorView: View {
    let project: EditorProjectReference?
    let hotReloadState: EditorHotReloadState
    @State private var viewModel = EditorViewModel()
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { geometry in
            let metrics = AdaEngineStyleLayoutMetrics(size: geometry.size)
            VStack(spacing: metrics.workspaceSpacer) {
                EditorTopToolbar(
                    hotReloadState: hotReloadState,
                    viewModel: viewModel.toolbar
                )
                .frame(height: metrics.topToolbarHeight)
                
                HStack(spacing: 0) {
                    EditorLeftToolStrip(viewModel: viewModel.toolStrip)
                        .frame(width: metrics.toolStripWidth)
                    
                    EditorWorkspaceView(
                        geometry: geometry,
                        viewModel: viewModel,
                        leftPanel: {
                            EditorProjectSidebar(viewModel: viewModel.projectSidebar)
                        },
                        mainPanel: {
                            EditorCenterWorkbench(viewModel: viewModel.workbench)
                                .frame(maxHeight: .infinity)
                        },
                        rightPanel: {
                            EditorInspectorSidebar(viewModel: viewModel.inspectorSidebar)
                        },
                        bottomPanel: {
                            EditorBottomPanel(viewModel: viewModel)
                        }
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .layoutPriority(2)
                    
                    EditorRightToolStrip(viewModel: viewModel.toolStrip)
                        .frame(width: metrics.toolStripWidth)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                EditorFooter(
                    hotReloadState: hotReloadState,
                    viewModel: viewModel.footer
                )
                .frame(height: metrics.footerHeight)
            }
            .foregroundColor(theme.editorColors.text)
            .environment(\.metrics, metrics)
        }
        .padding(.all, 4)
        .background {
            theme.editorColors.background
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .keyboardShortcut(.d, modifiers: .command) {
            viewModel.toggleDebugOverlay()
        }
        .debugOverlay(.redraw)
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

    @Environment(\.windowManager) private var windowManager
    
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
            .onHover { isHovered in
                windowManager?.setCursorShape(isHovered ? cursorShape : .arrow)
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        windowManager?.setCursorShape(cursorShape)
                        onResize(value.translation)
                    }
                    .onEnded { _ in
                        onResizeEnded()
                        windowManager?.setCursorShape(.arrow)
                    }
            )
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
