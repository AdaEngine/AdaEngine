@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
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
        #expect(AdaEngineStyleLayoutSpec.panelSpacing == 8)
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
        #expect(AdaEngineStyleContent.leftTopSidebarTools.map(\.title) == ["File Tree", "Entity Tree", "Source Control", "Tests"])
        #expect(AdaEngineStyleContent.leftBottomSidebarTools.map(\.title) == ["Logs", "Build", "Animator"])
        #expect(AdaEngineStyleContent.rightSidebarTools.map(\.title) == ["Agent Chat", "Inspector", "Project Dependencies", "Swift Package Tasks", "Plugins", "Project Settings"])
        #expect(AdaEngineStyleContent.projectTreeItems == ["src", "EngineLoop.ada", "Renderer.ada", "Main.ascn"])
        #expect(AdaEngineStyleContent.editorTabs.contains("Main.ascn"))
        #expect(AdaEngineStyleContent.outputTabs == ["Problems", "Build", "Tests", "References", "Output"])
    }

    @Test("sidebar tools use renderable compact glyphs")
    func sidebarToolsUseRenderableCompactGlyphs() {
        let allIcons = AdaEngineStyleContent.leftTopSidebarTools
            + AdaEngineStyleContent.leftBottomSidebarTools
            + AdaEngineStyleContent.rightSidebarTools
        let iconCodepoints = allIcons.compactMap { $0.icon.unicodeScalars.first?.value }

        #expect(iconCodepoints.count == allIcons.count)
        #expect(Set(iconCodepoints).isSubset(of: Set(AdaEditorMaterialSymbolFont.codepoints)))
        #expect(allIcons.allSatisfy { $0.icon.unicodeScalars.count == 1 })
    }

    @Test("AI flight box and inspector include requested interactive copy")
    func aiFlightBoxAndInspectorCopy() {
        #expect(AdaEngineStyleContent.aiTitle == "Ada Intelligence")
        #expect(AdaEngineStyleContent.aiHint == "⌘L to Focus")
        #expect(AdaEngineStyleContent.aiPlaceholder == "Ask to generate logic, optimize shaders, or place objects...")
        #expect(AdaEngineStyleContent.aiChips == ["Refactor current scene", "Optimize render batches", "Auto-light"])
        #expect(AdaEngineStyleContent.inspectorScript == "DynamicBouncer.ada")
        #expect(AdaEngineStyleContent.inspectorScriptDescription == "Object bounces on contact")
    }

    @Test("status and output panel include required runtime messages")
    func statusAndOutputMessages() {
        #expect(AdaEngineStyleContent.logLines.contains { $0.contains("Ada Engine initialized") })
        #expect(AdaEngineStyleContent.logLines.contains { $0.contains("AI optimization note") })
        #expect(AdaEngineStyleContent.footerLeft == ["Built in 142ms", "Renderer Ready"])
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
        #expect(viewModel.toolStrip.activeLeftTopTool == "fileTree")
        #expect(viewModel.toolStrip.activeLeftBottomTool == "logs")
        #expect(viewModel.toolStrip.activeRightTool == "agentChat")
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
        #expect(viewModel.showsDebugOverlay == nil)
        #expect(viewModel.playModeState == .editing)
    }

    @Test("editor view model mutates interaction state")
    @MainActor
    func editorViewModelMutatesInteractionState() {
        let viewModel = EditorViewModel()
        let hotReloadState = EditorHotReloadState(isEnabled: true, watchedPathCount: 2, lastReloadedPath: nil, errorMessage: nil)

        viewModel.toolbar.searchText = "Renderer"
        viewModel.toolStrip.selectRightTool(AdaEngineStyleContent.rightSidebarTools[5])
        viewModel.toolStrip.selectLeftBottomTool(AdaEngineStyleContent.leftBottomSidebarTools[0])
        viewModel.selectOutputTab("Terminal")
        viewModel.workbench.aiPrompt = "Generate a platformer controller"
        viewModel.workbench.hoveredChip = AdaEngineStyleContent.aiChips.first
        viewModel.toggleDebugOverlay(.layoutBounds)

        #expect(viewModel.toolbar.searchText == "Renderer")
        #expect(viewModel.toolStrip.activeRightTool == "projectSettings")
        #expect(viewModel.toolStrip.activeLeftTopTool == "fileTree")
        #expect(viewModel.toolStrip.activeLeftBottomTool == "logs")
        #expect(viewModel.activeOutputTab == "Terminal")
        #expect(viewModel.workbench.activeOutputTab == "Terminal")
        #expect(viewModel.workbench.aiPrompt == "Generate a platformer controller")
        #expect(viewModel.workbench.hoveredChip == "Refactor current scene")
        #expect(viewModel.footer.leftItems(hotReloadState: hotReloadState) == ["Built in 142ms", "Renderer Ready", "Hot Reload: 2 paths"])
        #expect(viewModel.showsDebugOverlay == .layoutBounds)
    }

    @Test("editor play mode runs active scene document from memory")
    @MainActor
    func editorPlayModeRunsActiveSceneDocumentFromMemory() throws {
        let viewModel = EditorViewModel()
        let sceneDocument = try #require(viewModel.workbench.activeSceneDocument)

        var editedDocument = sceneDocument
        editedDocument.content = SceneDocumentFormat.defaultSceneYAML(projectName: "UnsavedPlayScene")
        editedDocument.sceneModel = EditorSceneFileLoader.model(from: editedDocument.content)
        editedDocument.loadSummary = EditorSceneFileLoader.summary(from: editedDocument.content)
        editedDocument.isDirty = true
        viewModel.workbench.replaceSceneDocument(editedDocument)

        viewModel.runActiveSceneInEditor()

        #expect(viewModel.playModeState == .playing(sceneDocumentID: editedDocument.id, title: editedDocument.title))
        #expect(viewModel.workspaceStatus == .running("Play \(editedDocument.title)"))

        viewModel.stopPlayMode()
        #expect(viewModel.playModeState == .editing)
        #expect(viewModel.workspaceStatus == .ready)
    }

    @Test("editor play mode falls back to startup scene when active document is not a scene")
    @MainActor
    func editorPlayModeFallsBackToStartupScene() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorPlayStartupScene")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        try createPlayableProject(at: rootURL, sceneName: "StartupPlayScene")
        let project = EditorProjectReference(name: "EditorPlayStartupScene", path: rootURL.path)
        let viewModel = EditorViewModel(project: project)
        viewModel.workbench.selectDocument(id: "text:src/EngineLoop.ada")

        viewModel.runActiveSceneInEditor()

        #expect(viewModel.playModeState == .playing(sceneDocumentID: "scene:Assets/Scenes/Main.ascn", title: "Main.ascn"))
        let activeScene = try #require(viewModel.workbench.activeSceneDocument)
        #expect(activeScene.relativePath == "Assets/Scenes/Main.ascn")
        #expect(activeScene.content.contains("StartupPlayScene"))
    }

    @Test("editor play mode reports missing startup scene")
    @MainActor
    func editorPlayModeReportsMissingStartupScene() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorPlayMissingStartupScene")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        try createPlayableProject(at: rootURL, sceneName: "MissingStartupScene")
        try FileManager.default.removeItem(at: rootURL.appendingPathComponent(SceneDocumentFormat.defaultScenePath, isDirectory: false))

        let project = EditorProjectReference(name: "EditorPlayMissingStartupScene", path: rootURL.path)
        let viewModel = EditorViewModel(project: project)
        viewModel.workbench.selectDocument(id: "text:src/EngineLoop.ada")

        viewModel.runActiveSceneInEditor()

        #expect(viewModel.playModeState == .failed("Startup scene not found: Assets/Scenes/Main.ascn"))
        #expect(viewModel.workspaceStatus == .failed("Startup scene not found: Assets/Scenes/Main.ascn"))
    }

    @Test("inspector vector axis binding updates only the selected component")
    @MainActor
    func inspectorVectorAxisBindingUpdatesOnlySelectedComponent() {
        let viewModel = EditorInspectorSidebarViewModel()
        let positionField = EditorComponentField(key: "position", label: "Position", kind: .vector3)
        var appliedValue = ""

        viewModel.updateComponentField = { _, _, value in
            appliedValue = value
        }
        viewModel.selectEntity(
            EditorInspectorSidebarViewModel.SelectedEntity(
                editorID: "entity-1",
                name: "Player",
                componentNames: [EditorBuiltInComponentType.transform],
                transformFields: [EditorInspectorSidebarViewModel.TransformField(field: positionField, value: "1, 2, 3")],
                components: [
                    EditorInspectorSidebarViewModel.ComponentSection(
                        typeName: EditorBuiltInComponentType.transform,
                        displayName: "Transform",
                        fields: [
                            EditorInspectorSidebarViewModel.ComponentField(
                                typeName: EditorBuiltInComponentType.transform,
                                field: positionField,
                                value: "1, 2, 3"
                            )
                        ],
                        canRemove: false
                    )
                ],
                addableComponents: [],
                gizmo: nil,
                hasExplicitGizmo: false
            )
        )

        let yAxis = viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 1)
        #expect(yAxis.wrappedValue == "2")

        yAxis.wrappedValue = "20"

        #expect(appliedValue == "1, 20, 3")
        #expect(viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 0).wrappedValue == "1")
        #expect(viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 1).wrappedValue == "20")
        #expect(viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 2).wrappedValue == "3")
    }

    @Test("inspector vector axis binding keeps invalid drafts without clobbering model values")
    @MainActor
    func inspectorVectorAxisBindingKeepsInvalidDrafts() {
        let viewModel = EditorInspectorSidebarViewModel()
        let positionField = EditorComponentField(key: "position", label: "Position", kind: .vector3)
        var appliedValues: [String] = []

        viewModel.updateComponentField = { _, _, value in
            appliedValues.append(value)
        }
        viewModel.selectEntity(
            EditorInspectorSidebarViewModel.SelectedEntity(
                editorID: "entity-1",
                name: "Player",
                componentNames: [EditorBuiltInComponentType.transform],
                transformFields: [EditorInspectorSidebarViewModel.TransformField(field: positionField, value: "1, 2, 3")],
                components: [
                    EditorInspectorSidebarViewModel.ComponentSection(
                        typeName: EditorBuiltInComponentType.transform,
                        displayName: "Transform",
                        fields: [
                            EditorInspectorSidebarViewModel.ComponentField(
                                typeName: EditorBuiltInComponentType.transform,
                                field: positionField,
                                value: "1, 2, 3"
                            )
                        ],
                        canRemove: false
                    )
                ],
                addableComponents: [],
                gizmo: nil,
                hasExplicitGizmo: false
            )
        )

        let yAxis = viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 1)
        yAxis.wrappedValue = ""
        #expect(yAxis.wrappedValue == "")
        #expect(appliedValues.isEmpty)
        #expect(viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 0).wrappedValue == "1")
        #expect(viewModel.componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: positionField, axisIndex: 2).wrappedValue == "3")

        yAxis.wrappedValue = "-4.5"
        #expect(yAxis.wrappedValue == "-4.5")
        #expect(appliedValues == ["1, -4.5, 3"])
    }

    @Test("sidebar toolstrip toggles visible panels by region")
    @MainActor
    func sidebarToolstripTogglesVisiblePanelsByRegion() {
        let viewModel = EditorViewModel()
        let fileTree = AdaEngineStyleContent.leftTopSidebarTools[0]
        let build = AdaEngineStyleContent.leftBottomSidebarTools[1]
        let inspector = AdaEngineStyleContent.rightSidebarTools[1]
        let settings = AdaEngineStyleContent.rightSidebarTools[5]

        #expect(viewModel.showLeftPanel)
        #expect(viewModel.isLeftTopToolPresented(fileTree))
        viewModel.activateLeftTopTool(fileTree)
        #expect(!viewModel.showLeftPanel)
        #expect(!viewModel.isLeftTopToolPresented(fileTree))
        viewModel.activateLeftTopTool(fileTree)
        #expect(viewModel.showLeftPanel)
        #expect(viewModel.isLeftTopToolPresented(fileTree))

        viewModel.activateLeftBottomTool(build)
        #expect(viewModel.showBottomPanel)
        #expect(viewModel.toolStrip.activeLeftTopTool == "fileTree")
        #expect(viewModel.toolStrip.activeLeftBottomTool == "build")
        #expect(viewModel.isLeftTopToolPresented(fileTree))
        #expect(viewModel.isLeftBottomToolPresented(build))
        viewModel.activateLeftBottomTool(build)
        #expect(!viewModel.showBottomPanel)
        #expect(!viewModel.isLeftBottomToolPresented(build))
        #expect(viewModel.isLeftTopToolPresented(fileTree))
        viewModel.activateLeftBottomTool(build)
        #expect(viewModel.showBottomPanel)
        #expect(viewModel.isLeftBottomToolPresented(build))

        viewModel.activateRightTool(inspector)
        #expect(viewModel.showRightPanel)
        #expect(viewModel.isRightToolPresented(inspector))
        viewModel.activateRightTool(inspector)
        #expect(!viewModel.showRightPanel)
        #expect(!viewModel.isRightToolPresented(inspector))
        viewModel.activateRightTool(settings)
        #expect(viewModel.showRightPanel)
        #expect(viewModel.toolStrip.activeRightTool == "projectSettings")
        #expect(viewModel.isRightToolPresented(settings))
    }

    @Test("workbench closes tabs and keeps a valid active document")
    @MainActor
    func workbenchClosesTabs() {
        let workbench = EditorWorkbenchViewModel()
        let initialDocumentCount = workbench.openDocuments.count
        let inactiveDocumentID = workbench.openDocuments[0].id
        let activeDocumentID = workbench.activeDocumentID

        workbench.closeDocument(id: inactiveDocumentID)
        #expect(workbench.openDocuments.count == initialDocumentCount - 1)
        #expect(workbench.activeDocumentID == activeDocumentID)
        #expect(workbench.activeEditorTab == "Main.ascn")

        workbench.closeDocument(id: activeDocumentID)
        #expect(workbench.openDocuments.isEmpty)
        #expect(workbench.activeDocumentID == "")
        #expect(workbench.activeEditorTab == "")
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
        #expect(sceneDocument.loadSummary.entityCount == 0)
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

        viewModel.openProjectItemAsRaw(sceneItem)
        guard case .text(let rawDocument) = viewModel.workbench.activeDocument else {
            Issue.record("Expected a raw text document")
            return
        }
        #expect(rawDocument.id == "raw:Assets/Scenes/Main.ascn")
        #expect(rawDocument.language == .yaml)
        #expect(rawDocument.content.contains("schemaVersion: 2"))
    }

    @Test("editor saves text document on command save and tab switch")
    @MainActor
    func editorSavesTextDocumentOnCommandSaveAndTabSwitch() throws {
        let rootURL = try makeAdaEngineStyleUITemporaryDirectory(named: "EditorTextAutosave")
        defer { removeAdaEngineStyleUITemporaryDirectory(rootURL) }

        let sourcesURL = rootURL.appendingPathComponent("Sources/Game", isDirectory: true)
        let metadataURL = rootURL.appendingPathComponent(ProjectSystem.metadataDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: sourcesURL, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: metadataURL, withIntermediateDirectories: true)
        try "// swift-tools-version: 6.2\n".write(to: rootURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try "{}\n".write(to: metadataURL.appendingPathComponent(ProjectSystem.metadataFileName), atomically: true, encoding: .utf8)

        let mainURL = sourcesURL.appendingPathComponent("main.swift")
        let otherURL = sourcesURL.appendingPathComponent("Other.swift")
        try "let value = 1\n".write(to: mainURL, atomically: true, encoding: .utf8)
        try "let other = 2\n".write(to: otherURL, atomically: true, encoding: .utf8)

        let project = EditorProjectReference(name: "EditorTextAutosave", path: rootURL.path)
        let viewModel = EditorViewModel(project: project)
        let mainItem = try #require(viewModel.projectSidebar.items.first { $0.relativePath == "Sources/Game/main.swift" })
        let otherItem = try #require(viewModel.projectSidebar.items.first { $0.relativePath == "Sources/Game/Other.swift" })

        viewModel.openProjectItem(mainItem)
        let mainDocumentID = try #require(viewModel.workbench.activeDocument?.id)
        viewModel.workbench.updateTextDocument(id: mainDocumentID) { document in
            document.content = "let value = 42\n"
            document.isDirty = true
        }
        viewModel.saveActiveDocument()

        #expect(try String(contentsOf: mainURL, encoding: .utf8) == "let value = 42\n")
        guard case .text(let savedMainDocument)? = viewModel.workbench.activeDocument else {
            Issue.record("Expected the saved text document to remain active")
            return
        }
        #expect(!savedMainDocument.isDirty)
        #expect(savedMainDocument.statusMessage == "Saved")

        viewModel.workbench.updateTextDocument(id: mainDocumentID) { document in
            document.content = "let value = 99\n"
            document.isDirty = true
        }
        viewModel.openProjectItem(otherItem)

        #expect(try String(contentsOf: mainURL, encoding: .utf8) == "let value = 99\n")
        guard case .text(let otherDocument)? = viewModel.workbench.activeDocument else {
            Issue.record("Expected tab switch to activate the other text document")
            return
        }
        #expect(otherDocument.absolutePath?.hasSuffix("Sources/Game/Other.swift") == true)
    }

    @Test("editor scene loader instantiates known entities and components")
    @MainActor
    func editorSceneLoaderInstantiatesKnownEntitiesAndComponents() {
        Transform.registerComponent()

        let world = World()
        let result = EditorSceneFileLoader.load(content: SceneDocumentFormat.defaultSceneYAML(projectName: "Main"), into: world)
        let entities = world.getEntities()

        #expect(result.entityCount == 1)
        #expect(result.warnings.isEmpty)
        #expect(entities.count == 1)
        #expect(entities.first?.name == "Root")
        #expect(entities.first?.components[Transform.self] != nil)
    }

    @Test("editor scene loader reports unknown components without failing")
    @MainActor
    func editorSceneLoaderReportsUnknownComponentsWithoutFailing() {
        let content = SceneDocumentFormat.defaultSceneYAML(projectName: "Main")
            .replacingOccurrences(of: "AdaTransform.Transform:", with: "Game.UnknownComponent:")

        let world = World()
        let result = EditorSceneFileLoader.load(content: content, into: world)

        #expect(result.entityCount == 1)
        #expect(result.warnings.contains("Unknown component: Game.UnknownComponent"))
        #expect(world.getEntities().count == 1)
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
        #expect(tokens.contains(EditorCodeToken(text: "Ada", color: .blue)))
        #expect(tokens.contains(EditorCodeToken(text: "// comment", color: .red)))
    }

    @Test("syntax highlighter supports JSON and YAML")
    func syntaxHighlighterSupportsJSONAndYAML() {
        var palette = EditorCodeColorPalette.dark
        palette.keyword = .green
        palette.string = .blue
        palette.number = .red
        palette.comment = .yellow
        palette.type = .orange

        let jsonTokens = EditorSyntaxHighlighter.tokens(
            for: #"{"name":"Ada","enabled":true,"count":12}"#,
            language: .json,
            palette: palette
        )
        #expect(jsonTokens.contains(EditorCodeToken(text: #""Ada""#, color: .blue)))
        #expect(jsonTokens.contains(EditorCodeToken(text: "true", color: .green)))
        #expect(jsonTokens.contains(EditorCodeToken(text: "12", color: .red)))

        let yamlTokens = EditorSyntaxHighlighter.tokens(
            for: "name: Ada\ncount: 12 # generated",
            language: .yaml,
            palette: palette
        )
        #expect(yamlTokens.contains(EditorCodeToken(text: "name", color: .orange)))
        #expect(yamlTokens.contains(EditorCodeToken(text: "12", color: .red)))
        #expect(yamlTokens.contains(EditorCodeToken(text: "# generated", color: .yellow)))
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

private func createPlayableProject(at rootURL: URL, sceneName: String) throws {
    let scenesURL = rootURL.appendingPathComponent("Assets/Scenes", isDirectory: true)
    try FileManager.default.createDirectory(at: scenesURL, withIntermediateDirectories: true)
    try "// swift-tools-version: 6.2\n".write(to: rootURL.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
    try SceneDocumentFormat.defaultSceneYAML(projectName: sceneName).write(
        to: rootURL.appendingPathComponent(SceneDocumentFormat.defaultScenePath, isDirectory: false),
        atomically: true,
        encoding: .utf8
    )
    _ = try ProjectSystem.createDefaultProject(at: rootURL)
}
