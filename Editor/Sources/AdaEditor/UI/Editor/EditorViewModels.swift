@_spi(AdaEngine) import AdaEngine
import Observation

@Observable
@MainActor
final class EditorToolbarViewModel {
    var searchText: String
    var sceneName: String

    init(searchText: String = "", sceneName: String = "main_scene") {
        self.searchText = searchText
        self.sceneName = sceneName
    }

    var searchTextBinding: Binding<String> {
        Binding(get: { self.searchText }, set: { self.searchText = $0 })
    }
}

@Observable
@MainActor
final class EditorToolStripViewModel {
    var hoveredTool: String?
    var activeLeftTool: String
    var activeRightTool: String

    init(hoveredTool: String? = nil, activeLeftTool: String = "Project", activeRightTool: String = "AI") {
        self.hoveredTool = hoveredTool
        self.activeLeftTool = activeLeftTool
        self.activeRightTool = activeRightTool
    }
}

@Observable
@MainActor
final class EditorProjectSidebarViewModel {
    struct Item: Equatable {
        var disclosure: String
        var icon: String
        var title: String
        var level: Int
        var isActive: Bool
        var isFolder: Bool
    }

    var items: [Item]

    init(items: [Item] = [
        Item(disclosure: "", icon: "▱", title: "src", level: 0, isActive: false, isFolder: true),
        Item(disclosure: "", icon: "▱", title: "EngineLoop.ada", level: 1, isActive: true, isFolder: false),
        Item(disclosure: "", icon: "▱", title: "Renderer.ada", level: 1, isActive: false, isFolder: false)
    ]) {
        self.items = items
    }
}

@Observable
@MainActor
final class EditorWorkbenchViewModel {
    var aiPrompt: String
    var hoveredChip: String?
    var activeEditorTab: String
    var activeOutputTab: String

    init(
        aiPrompt: String = "",
        hoveredChip: String? = nil,
        activeEditorTab: String = "MainLevel.scene",
        activeOutputTab: String = "Problems"
    ) {
        self.aiPrompt = aiPrompt
        self.hoveredChip = hoveredChip
        self.activeEditorTab = activeEditorTab
        self.activeOutputTab = activeOutputTab
    }

    var aiPromptBinding: Binding<String> {
        Binding(get: { self.aiPrompt }, set: { self.aiPrompt = $0 })
    }
}

@Observable
@MainActor
final class EditorInspectorSidebarViewModel {
    struct TransformField: Equatable {
        var label: String
        var value: String
    }

    var transformFields: [TransformField]
    var scriptName: String
    var scriptDescription: String

    init(
        transformFields: [TransformField] = [
            TransformField(label: "Position", value: "0.0, 1.2, -5.4"),
            TransformField(label: "Rotation", value: "0, 180, 0")
        ],
        scriptName: String = AdaEngineStyleContent.inspectorScript,
        scriptDescription: String = AdaEngineStyleContent.inspectorScriptDescription
    ) {
        self.transformFields = transformFields
        self.scriptName = scriptName
        self.scriptDescription = scriptDescription
    }
}

@Observable
@MainActor
final class EditorFooterViewModel {
    var leftItems: [String]
    var rightItems: [String]

    init(leftItems: [String] = AdaEngineStyleContent.footerLeft, rightItems: [String] = AdaEngineStyleContent.footerRight) {
        self.leftItems = leftItems
        self.rightItems = rightItems
    }

    func leftItems(hotReloadState: EditorHotReloadState) -> [String] {
        leftItems + [hotReloadState.footerTitle]
    }
}

@Observable
@MainActor
final class EditorViewModel {
    var toolbar: EditorToolbarViewModel
    var toolStrip: EditorToolStripViewModel
    var projectSidebar: EditorProjectSidebarViewModel
    var workbench: EditorWorkbenchViewModel
    var inspectorSidebar: EditorInspectorSidebarViewModel
    var footer: EditorFooterViewModel
    var showsDebugOverlay: Bool
    var activeOutputTab: String
    
    var showLeftPanel = true
    var showRightPanel = true
    var showBottomPanel = true

    init(
        toolbar: EditorToolbarViewModel = EditorToolbarViewModel(),
        toolStrip: EditorToolStripViewModel = EditorToolStripViewModel(),
        projectSidebar: EditorProjectSidebarViewModel = EditorProjectSidebarViewModel(),
        workbench: EditorWorkbenchViewModel = EditorWorkbenchViewModel(),
        inspectorSidebar: EditorInspectorSidebarViewModel = EditorInspectorSidebarViewModel(),
        footer: EditorFooterViewModel = EditorFooterViewModel(),
        activeOutputTab: String = "Problems",
        showsDebugOverlay: Bool = false
    ) {
        self.toolbar = toolbar
        self.toolStrip = toolStrip
        self.projectSidebar = projectSidebar
        self.workbench = workbench
        self.inspectorSidebar = inspectorSidebar
        self.activeOutputTab = activeOutputTab
        self.footer = footer
        self.showsDebugOverlay = showsDebugOverlay
    }

    func toggleDebugOverlay() {
        showsDebugOverlay.toggle()
    }
}
