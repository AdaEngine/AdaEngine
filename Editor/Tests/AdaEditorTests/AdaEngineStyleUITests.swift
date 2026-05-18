@testable import AdaEditor
import AdaInput
@_spi(Internal) import AdaUI
import AdaUtils
import Foundation
import Math
import Testing

@Suite("AdaEngineStyle UI mock")
struct AdaEngineStyleUITests {
    @Test("desktop grid dimensions match the requested IDE layout")
    func desktopGridDimensions() {
        #expect(AdaEngineStyleLayoutSpec.topToolbarHeight == 52)
        #expect(AdaEngineStyleLayoutSpec.toolStripWidth == 40)
        #expect(AdaEngineStyleLayoutSpec.projectSidebarWidth == 260)
        #expect(AdaEngineStyleLayoutSpec.inspectorWidth == 300)
        #expect(AdaEngineStyleLayoutSpec.footerHeight == 24)
        #expect(AdaEngineStyleLayoutSpec.minimumWidth < AdaEngineStyleLayoutSpec.windowWidth)
        #expect(AdaEngineStyleLayoutSpec.minimumHeight < AdaEngineStyleLayoutSpec.windowHeight)
        #expect(AdaEngineStyleLayoutSpec.aiFlightBoxCompactWidth < AdaEngineStyleLayoutSpec.aiFlightBoxWidth)
    }

    @Test("layout metrics adapt to smaller windows")
    func layoutMetricsAdaptToSmallerWindows() {
        let desktop = AdaEngineStyleLayoutMetrics(size: Size(width: 1280, height: 820))
        let compact = AdaEngineStyleLayoutMetrics(size: Size(width: 700, height: 420))

        #expect(desktop.showsProjectSidebar)
        #expect(desktop.showsInspectorSidebar)
        #expect(!compact.showsProjectSidebar)
        #expect(!compact.showsInspectorSidebar)
        #expect(compact.toolbarSearchWidth < desktop.toolbarSearchWidth)
        #expect(compact.aiFlightBoxWidth <= compact.workbenchWidth)
        #expect(compact.aiFlightBoxHeight < desktop.aiFlightBoxHeight)
        #expect(compact.outputTabs.count < AdaEngineStyleContent.outputTabs.count)
    }

    @Test("all required IDE regions expose reference labels")
    func requiredReferenceLabels() {
        #expect(AdaEngineStyleContent.topToolbarLabels.contains("Search Everywhere"))
        #expect(AdaEngineStyleContent.topToolbarLabels.contains("main_scene"))
        #expect(AdaEngineStyleContent.leftTopSidebarTools.map(\.title) == ["File Tree", "Entity Tree", "Agent Chat", "Source Control", "Tests"])
        #expect(AdaEngineStyleContent.leftBottomSidebarTools.map(\.title) == ["Logs", "Build", "Animator"])
        #expect(AdaEngineStyleContent.rightSidebarTools.map(\.title) == ["Inspector", "Project Dependencies", "Swift Package Tasks", "Plugins", "Project Settings"])
        #expect(AdaEngineStyleContent.projectTreeItems == ["src", "EngineLoop.ada", "Renderer.ada", "Main.ascn"])
        #expect(AdaEngineStyleContent.editorTabs.contains("Main.ascn"))
        #expect(AdaEngineStyleContent.outputTabs == ["Problems", "Output", "Terminal", "Vulkan Profiler", "AI Chat History"])
    }

    @Test("sidebar tools use Material Symbols codepoints")
    func sidebarToolsUseMaterialSymbolsCodepoints() {
        #expect(AdaEngineStyleContent.leftTopSidebarTools.map(\.icon) == ["\u{E2C7}", "\u{E97A}", "\u{F06C}", "\u{EAF5}", "\u{EA4B}"])
        #expect(AdaEngineStyleContent.leftBottomSidebarTools.map(\.icon) == ["\u{EB8E}", "\u{E869}", "\u{E71C}"])
        #expect(AdaEngineStyleContent.rightSidebarTools.map(\.icon) == ["\u{E88E}", "\u{E9F4}", "\u{F569}", "\u{E87B}", "\u{E8B8}"])
    }

    @Test("AI flight box and inspector include requested interactive copy")
    func aiFlightBoxAndInspectorCopy() {
        #expect(AdaEngineStyleContent.aiTitle == "Ada Intelligence")
        #expect(AdaEngineStyleContent.aiHint == "⌘L to Focus")
        #expect(AdaEngineStyleContent.aiPlaceholder == "Ask to generate logic, optimize shaders, or place objects...")
        #expect(AdaEngineStyleContent.aiChips == ["Refactor current scene", "Optimize Vulkan DrawCalls", "Auto-light"])
        #expect(AdaEngineStyleContent.inspectorScript == "DynamicBouncer.ada")
        #expect(AdaEngineStyleContent.inspectorScriptDescription == "Object bounces on contact")
    }

    @Test("status and output panel include required runtime messages")
    func statusAndOutputMessages() {
        #expect(AdaEngineStyleContent.logLines.contains { $0.contains("Ada Engine initialized") })
        #expect(AdaEngineStyleContent.logLines.contains { $0.contains("AI optimization note") })
        #expect(AdaEngineStyleContent.footerLeft == ["Built in 142ms", "Vulkan Enabled"])
        #expect(AdaEngineStyleContent.footerRight == ["3:12 LF UTF-8", "Git: main*"])
    }

    @Test("hot reload state exposes compact toolbar and footer labels")
    func hotReloadStateLabels() {
        let ready = EditorHotReloadState(isEnabled: true, watchedPathCount: 3, lastReloadedPath: nil, errorMessage: nil)
        let reloaded = EditorHotReloadState(isEnabled: true, watchedPathCount: 3, lastReloadedPath: "main.swift", errorMessage: nil)
        let failed = EditorHotReloadState(isEnabled: false, watchedPathCount: 3, lastReloadedPath: nil, errorMessage: "Permission denied")

        #expect(ready.toolbarTitle == "↻ Hot Reload")
        #expect(ready.footerTitle == "Hot Reload: 3 paths")
        #expect(reloaded.toolbarTitle == "↻ Reloaded")
        #expect(reloaded.footerTitle == "Hot Reload: main.swift")
        #expect(failed.toolbarTitle == "↻ Hot Reload Failed")
        #expect(failed.footerTitle == "Hot Reload: Permission denied")
    }

    @Test("hot reload watch paths use project metadata and ignore missing directories")
    func hotReloadWatchPathsUseProjectMetadata() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorHotReloadPaths")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        let sourcesURL = rootURL.appendingPathComponent("GameSources", isDirectory: true)
        let assetsURL = rootURL.appendingPathComponent("GameAssets", isDirectory: true)
        let metadataURL = rootURL.appendingPathComponent(ProjectSystem.metadataDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: assetsURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: true)

        let metadata = AdaProject(
            schemaVersion: ProjectSystem.currentSchemaVersion,
            paths: AdaProjectPaths(sources: "GameSources", assets: "GameAssets")
        )
        let urls = EditorHotReloadConfiguration.watchedDirectoryURLs(forProjectAt: rootURL, metadata: metadata)
            .map(\.path)

        #expect(urls == [
            sourcesURL.resolvingSymlinksInPath().path,
            assetsURL.resolvingSymlinksInPath().path,
            metadataURL.resolvingSymlinksInPath().path
        ])
    }

    @Test("hot reload watch paths deduplicate matching source and asset directories")
    func hotReloadWatchPathsDeduplicateDirectories() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorHotReloadDeduplicate")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        let sharedURL = rootURL.appendingPathComponent("Sources", isDirectory: true)
        let metadataURL = rootURL.appendingPathComponent(ProjectSystem.metadataDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: sharedURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: true)

        let metadata = AdaProject(
            schemaVersion: ProjectSystem.currentSchemaVersion,
            paths: AdaProjectPaths(sources: "Sources", assets: "Sources")
        )
        let urls = EditorHotReloadConfiguration.watchedDirectoryURLs(forProjectAt: rootURL, metadata: metadata)
            .map(\.path)

        #expect(urls == [
            sharedURL.resolvingSymlinksInPath().path,
            metadataURL.resolvingSymlinksInPath().path
        ])
    }

    @Test("editor theme exposes AdaUI theme tokens")
    func editorThemeExposesAdaUIThemeTokens() {
        var theme = Theme.adaEditor
        let defaultColors = theme.editorColors

        #expect(defaultColors == EditorThemeColors.dark)
        #expect(defaultColors.background == Color(red: 30 / 255, green: 31 / 255, blue: 34 / 255))
        #expect(defaultColors.text == Color(red: 223 / 255, green: 225 / 255, blue: 229 / 255))

        var overriddenColors = defaultColors
        overriddenColors.blue = .green
        theme.editorColors = overriddenColors

        #expect(theme.editorColors.blue == .green)
        #expect(theme.editorColors.background == defaultColors.background)
    }

    @Test("editor view model exposes observable editor state defaults")
    @MainActor
    func editorViewModelDefaults() {
        let viewModel = EditorViewModel()

        #expect(viewModel.toolbar.sceneName == "main_scene")
        #expect(viewModel.toolStrip.activeLeftTool == "fileTree")
        #expect(viewModel.toolStrip.activeRightTool == "inspector")
        #expect(viewModel.toolStrip.leftTopTools == AdaEngineStyleContent.leftTopSidebarTools)
        #expect(viewModel.toolStrip.leftBottomTools == AdaEngineStyleContent.leftBottomSidebarTools)
        #expect(viewModel.toolStrip.rightTools == AdaEngineStyleContent.rightSidebarTools)
        #expect(viewModel.projectSidebar.items.map(\.title) == AdaEngineStyleContent.projectTreeItems)
        #expect(viewModel.workbench.activeEditorTab == "Main.ascn")
        #expect(viewModel.workbench.activeOutputTab == "Problems")
        #expect(viewModel.workbench.openDocuments.map(\.title) == AdaEngineStyleContent.editorTabs)
        #expect(viewModel.workbench.codeColorPalette == EditorCodeColorPalette.dark)
        #expect(viewModel.inspectorSidebar.scriptName == AdaEngineStyleContent.inspectorScript)
        #expect(viewModel.footer.rightItems == AdaEngineStyleContent.footerRight)
        #expect(!viewModel.showsDebugOverlay)
    }

    @Test("editor view model mutates interaction state")
    @MainActor
    func editorViewModelMutatesInteractionState() {
        let viewModel = EditorViewModel()
        let hotReloadState = EditorHotReloadState(isEnabled: true, watchedPathCount: 2, lastReloadedPath: nil, errorMessage: nil)

        viewModel.toolbar.searchText = "Renderer"
        viewModel.toolStrip.selectRightTool(AdaEngineStyleContent.rightSidebarTools[4])
        viewModel.toolStrip.selectLeftTool(AdaEngineStyleContent.leftBottomSidebarTools[0])
        viewModel.workbench.aiPrompt = "Generate a platformer controller"
        viewModel.workbench.hoveredChip = AdaEngineStyleContent.aiChips.first
        viewModel.toggleDebugOverlay()

        #expect(viewModel.toolbar.searchText == "Renderer")
        #expect(viewModel.toolStrip.activeRightTool == "projectSettings")
        #expect(viewModel.toolStrip.activeLeftTool == "logs")
        #expect(viewModel.workbench.aiPrompt == "Generate a platformer controller")
        #expect(viewModel.workbench.hoveredChip == "Refactor current scene")
        #expect(viewModel.footer.leftItems(hotReloadState: hotReloadState) == ["Built in 142ms", "Vulkan Enabled", "Hot Reload: 2 paths"])
        #expect(viewModel.showsDebugOverlay)
    }

    @Test("editor opens text files as code documents and scene files as editable scene documents")
    @MainActor
    func editorOpensTextAndSceneProjectFiles() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorProjectDocuments")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        let sourcesURL = rootURL.appendingPathComponent("Sources/Game", isDirectory: true)
        let scenesURL = rootURL.appendingPathComponent("Assets/Scenes", isDirectory: true)
        let metadataURL = rootURL.appendingPathComponent(ProjectSystem.metadataDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: scenesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: rootURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "{}\n".write(to: rootURL.appendingPathComponent("Package.resolved"), atomically: true, encoding: .utf8)
        try "{}\n".write(to: metadataURL.appendingPathComponent(ProjectSystem.metadataFileName), atomically: true, encoding: .utf8)
        try "import AdaEngine\n\nstruct GameScene {}\n".write(to: sourcesURL.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)
        try "format: ada.scene\nschemaVersion: 1\n".write(to: scenesURL.appendingPathComponent("Main.ascn"), atomically: true, encoding: .utf8)

        let project = EditorProjectReference(name: "EditorProjectDocuments", path: rootURL.path)
        let viewModel = EditorViewModel(project: project)

        #expect(!viewModel.projectSidebar.items.contains { $0.relativePath == "Package.swift" })
        #expect(!viewModel.projectSidebar.items.contains { $0.relativePath == "Package.resolved" })
        #expect(!viewModel.projectSidebar.items.contains { $0.relativePath.hasPrefix(ProjectSystem.metadataDirectoryName) })

        let swiftItem = try #require(viewModel.projectSidebar.items.first { $0.relativePath == "Sources/Game/main.swift" })
        viewModel.openProjectItem(swiftItem)

        guard case .text(let textDocument) = viewModel.workbench.activeDocument else {
            Issue.record("Expected a text document")
            return
        }
        #expect(textDocument.title == "main.swift")
        #expect(textDocument.language == .swift)
        #expect(textDocument.content.contains("struct GameScene"))

        let sceneItem = try #require(viewModel.projectSidebar.items.first { $0.relativePath == "Assets/Scenes/Main.ascn" })
        viewModel.openProjectItem(sceneItem)

        guard case .scene(let sceneDocument) = viewModel.workbench.activeDocument else {
            Issue.record("Expected a scene document")
            return
        }
        #expect(sceneDocument.title == "Main.ascn")
        #expect(sceneDocument.content.contains("format: ada.scene"))
        #expect(sceneDocument.isDirty == false)
        viewModel.workbench.updateSceneLine(documentID: sceneDocument.id, lineIndex: 1, value: "schemaVersion: 2")
        guard case .scene(let editedSceneDocument) = viewModel.workbench.activeDocument else {
            Issue.record("Expected an edited scene document")
            return
        }
        #expect(editedSceneDocument.content.contains("schemaVersion: 2"))
        #expect(editedSceneDocument.isDirty)
        viewModel.workbench.saveSceneDocument(id: editedSceneDocument.id)
        #expect(try String(contentsOf: scenesURL.appendingPathComponent("Main.ascn"), encoding: .utf8).contains("schemaVersion: 2"))
        #expect(viewModel.workbench.activeEditorTab == "Main.ascn")
        #expect(viewModel.toolbar.sceneName == "Main")
    }

    @Test("project sidebar folders can collapse and expand")
    @MainActor
    func projectSidebarFoldersCollapseAndExpand() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorProjectSidebarCollapse")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        let sourcesURL = rootURL.appendingPathComponent("Sources/Game", isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try "import AdaEngine\n".write(to: sourcesURL.appendingPathComponent("main.swift"), atomically: true, encoding: .utf8)

        let project = EditorProjectReference(name: "EditorProjectSidebarCollapse", path: rootURL.path)
        let viewModel = EditorViewModel(project: project)
        let sourcesItem = try #require(viewModel.projectSidebar.items.first { $0.relativePath == "Sources" })

        #expect(viewModel.projectSidebar.visibleItems.contains { $0.relativePath == "Sources/Game/main.swift" })
        viewModel.openProjectItem(sourcesItem)
        #expect(viewModel.projectSidebar.isCollapsed(sourcesItem))
        #expect(!viewModel.projectSidebar.visibleItems.contains { $0.relativePath == "Sources/Game/main.swift" })
        viewModel.openProjectItem(sourcesItem)
        #expect(!viewModel.projectSidebar.isCollapsed(sourcesItem))
        #expect(viewModel.projectSidebar.visibleItems.contains { $0.relativePath == "Sources/Game/main.swift" })
    }

    @Test("syntax highlighter uses configurable code palette")
    func syntaxHighlighterUsesConfigurableCodePalette() {
        var palette = EditorCodeColorPalette.dark
        palette.keyword = .green
        palette.string = .blue
        palette.comment = .red

        let tokens = EditorSyntaxHighlighter.tokens(
            for: #"let title = "Ada" // comment"#,
            language: .swift,
            palette: palette
        )

        #expect(tokens.contains(EditorCodeToken(text: "let", color: .green)))
        #expect(tokens.contains(EditorCodeToken(text: #""Ada""#, color: .blue)))
        #expect(tokens.contains(EditorCodeToken(text: "// comment", color: .red)))
    }

    @Test("editor window drag passthrough delegates to interactive content")
    @MainActor
    func editorWindowDragPassthroughDelegatesToInteractiveContent() {
        let passthroughView = EditorWindowDragPassthroughView()
        passthroughView.frame = Rect(x: 0, y: 0, width: 320, height: 80)
        passthroughView.bounds.size = passthroughView.frame.size

        let interactiveSubview = UIView(frame: Rect(x: 40, y: 0, width: 160, height: 52))
        passthroughView.addSubview(interactiveSubview)

        let eventOnInteractiveContent = MouseEvent(
            window: RID(),
            button: .left,
            mousePosition: Point(x: 80, y: 20),
            phase: .began,
            modifierKeys: [],
            time: 0
        )
        let eventOnEmptyToolbarArea = MouseEvent(
            window: RID(),
            button: .left,
            mousePosition: Point(x: 260, y: 20),
            phase: .began,
            modifierKeys: [],
            time: 0
        )

        #expect(!passthroughView.uiAllowsWindowDrag(at: eventOnInteractiveContent.mousePosition, with: eventOnInteractiveContent))
        #expect(passthroughView.uiAllowsWindowDrag(at: eventOnEmptyToolbarArea.mousePosition, with: eventOnEmptyToolbarArea))
    }

    @Test("editor window content resizes to full window bounds")
    @MainActor
    func editorWindowContentResizesToFullWindowBounds() throws {
        let previousManager = UIWindowManager.shared
        let testManager = EditorWindowTestWindowManager()
        UIWindowManager.setShared(testManager)
        defer {
            if let previousManager {
                UIWindowManager.setShared(previousManager)
            }
        }

        let window = EditorWindow(frame: Rect(x: 0, y: 0, width: 640, height: 480))
        let resizedFrame = Rect(x: 0, y: 0, width: 1180, height: 760)
        window.frame = resizedFrame

        let inspectableView = try #require(window.inspectableView)
        #expect(inspectableView.frame == Rect(origin: .zero, size: resizedFrame.size))
        #expect(inspectableView.bounds.size == resizedFrame.size)

        let editorContentView = try #require(inspectableView.subviews.first)
        #expect(editorContentView.frame == Rect(origin: .zero, size: resizedFrame.size))
        #expect(editorContentView.bounds.size == resizedFrame.size)
    }
}

@MainActor
private final class EditorWindowTestWindowManager: UIWindowManager {
    override func showWindow(_ window: UIWindow, isFocused: Bool) {}
    override func closeWindow(_ window: UIWindow) {}
    override func setWindowMode(_ window: UIWindow, mode: UIWindow.Mode) {}
    override func setMinimumSize(_ size: Size, for window: UIWindow) {}
    override func resizeWindow(_ window: UIWindow, size: Size) {}
    override func getScreen(for window: UIWindow) -> Screen? { nil }
}

private func makeAdaEngineStyleUITemporaryDirectory(named name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(name, isDirectory: true)
    try? FileManager.default.removeItem(at: url)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func removeAdaEngineStyleUITemporaryDirectory(_ url: URL) {
    try? FileManager.default.removeItem(at: url)
}
