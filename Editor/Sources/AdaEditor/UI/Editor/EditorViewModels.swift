@_spi(AdaEngine) import AdaEngine
import Foundation
import Observation

struct EditorToolStripItem: Equatable, Sendable {
    var identifier: String
    var title: String
    var icon: String
}

struct EditorCodeColorPalette: Hashable, Sendable {
    var plainText: Color
    var keyword: Color
    var type: Color
    var string: Color
    var number: Color
    var comment: Color
    var punctuation: Color
    var lineNumber: Color
    var currentLineBackground: Color
    var selection: Color

    static let dark = EditorCodeColorPalette(
        plainText: Color(red: 214 / 255, green: 217 / 255, blue: 224 / 255),
        keyword: Color(red: 197 / 255, green: 134 / 255, blue: 252 / 255),
        type: Color(red: 78 / 255, green: 201 / 255, blue: 176 / 255),
        string: Color(red: 214 / 255, green: 157 / 255, blue: 133 / 255),
        number: Color(red: 181 / 255, green: 206 / 255, blue: 168 / 255),
        comment: Color(red: 106 / 255, green: 153 / 255, blue: 85 / 255),
        punctuation: Color(red: 172 / 255, green: 176 / 255, blue: 190 / 255),
        lineNumber: Color(red: 101 / 255, green: 108 / 255, blue: 122 / 255),
        currentLineBackground: Color(red: 43 / 255, green: 45 / 255, blue: 52 / 255),
        selection: Color(red: 53 / 255, green: 116 / 255, blue: 240 / 255).opacity(0.24)
    )
}

enum EditorSourceLanguage: String, Sendable {
    case ada
    case c
    case cpp
    case glsl
    case json
    case markdown
    case metal
    case packageManifest
    case plainText
    case swift
    case yaml

    static func detect(fileName: String) -> EditorSourceLanguage {
        let lowercasedName = fileName.lowercased()
        let fileExtension = URL(fileURLWithPath: lowercasedName).pathExtension

        if lowercasedName == "package.swift" {
            return .packageManifest
        }

        switch fileExtension {
        case "ada":
            return .ada
        case "c", "h":
            return .c
        case "cc", "cpp", "cxx", "hpp", "hxx":
            return .cpp
        case "frag", "glsl", "shader", "vert":
            return .glsl
        case "json":
            return .json
        case "md", "markdown":
            return .markdown
        case "metal":
            return .metal
        case "swift":
            return .swift
        case "yaml", "yml":
            return .yaml
        default:
            return .plainText
        }
    }
}

enum EditorProjectFileKind: Equatable, Sendable {
    case folder
    case scene
    case text(EditorSourceLanguage)
    case unsupported
}

struct EditorTextDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var language: EditorSourceLanguage
    var content: String
    var errorMessage: String?
}

struct EditorSceneDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var absolutePath: String?
    var content: String
    var errorMessage: String?
    var isDirty: Bool
    var statusMessage: String?
}

enum EditorWorkbenchDocument: Equatable, Sendable {
    case scene(EditorSceneDocument)
    case text(EditorTextDocument)

    var id: String {
        switch self {
        case .scene(let document):
            document.id
        case .text(let document):
            document.id
        }
    }

    var title: String {
        switch self {
        case .scene(let document):
            document.title
        case .text(let document):
            document.title
        }
    }

    var relativePath: String {
        switch self {
        case .scene(let document):
            document.relativePath
        case .text(let document):
            document.relativePath
        }
    }
}

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
    var activeLeftTool: String
    var activeRightTool: String
    var leftTopTools: [EditorToolStripItem]
    var leftBottomTools: [EditorToolStripItem]
    var rightTools: [EditorToolStripItem]

    init(
        activeLeftTool: String = "fileTree",
        activeRightTool: String = "inspector",
        leftTopTools: [EditorToolStripItem] = AdaEngineStyleContent.leftTopSidebarTools,
        leftBottomTools: [EditorToolStripItem] = AdaEngineStyleContent.leftBottomSidebarTools,
        rightTools: [EditorToolStripItem] = AdaEngineStyleContent.rightSidebarTools
    ) {
        self.activeLeftTool = activeLeftTool
        self.activeRightTool = activeRightTool
        self.leftTopTools = leftTopTools
        self.leftBottomTools = leftBottomTools
        self.rightTools = rightTools
    }

    func selectLeftTool(_ item: EditorToolStripItem) {
        activeLeftTool = item.identifier
    }

    func selectRightTool(_ item: EditorToolStripItem) {
        activeRightTool = item.identifier
    }
}

@Observable
@MainActor
final class EditorProjectSidebarViewModel {
    struct Item: Equatable {
        var id: String
        var disclosure: String
        var icon: String
        var title: String
        var relativePath: String
        var level: Int
        var isActive: Bool
        var isFolder: Bool
        var kind: EditorProjectFileKind
    }

    var items: [Item]
    var collapsedFolderIDs: Set<String>

    var visibleItems: [Item] {
        items.filter { !isHiddenByCollapsedFolder($0) }
    }

    init(items: [Item] = [
        Item(id: "src", disclosure: "", icon: "▱", title: "src", relativePath: "src", level: 0, isActive: false, isFolder: true, kind: .folder),
        Item(
            id: "src/EngineLoop.ada",
            disclosure: "",
            icon: "▱",
            title: "EngineLoop.ada",
            relativePath: "src/EngineLoop.ada",
            level: 1,
            isActive: true,
            isFolder: false,
            kind: .text(.ada)
        ),
        Item(
            id: "src/Renderer.ada",
            disclosure: "",
            icon: "▱",
            title: "Renderer.ada",
            relativePath: "src/Renderer.ada",
            level: 1,
            isActive: false,
            isFolder: false,
            kind: .text(.ada)
        ),
        Item(
            id: "Assets/Scenes/Main.ascn",
            disclosure: "",
            icon: "▱",
            title: "Main.ascn",
            relativePath: "Assets/Scenes/Main.ascn",
            level: 1,
            isActive: false,
            isFolder: false,
            kind: .scene
        )
    ], collapsedFolderIDs: Set<String> = []) {
        self.items = items
        self.collapsedFolderIDs = collapsedFolderIDs
    }

    func select(_ selectedItem: Item) {
        for index in items.indices {
            items[index].isActive = items[index].id == selectedItem.id
        }
    }

    func toggleFolder(_ item: Item) {
        guard item.isFolder else {
            return
        }

        if collapsedFolderIDs.contains(item.id) {
            collapsedFolderIDs.remove(item.id)
        } else {
            collapsedFolderIDs.insert(item.id)
        }
    }

    func isCollapsed(_ item: Item) -> Bool {
        item.isFolder && collapsedFolderIDs.contains(item.id)
    }

    private func isHiddenByCollapsedFolder(_ item: Item) -> Bool {
        collapsedFolderIDs.contains { collapsedFolderID in
            guard
                item.id != collapsedFolderID,
                let collapsedFolder = items.first(where: { $0.id == collapsedFolderID })
            else {
                return false
            }

            return item.relativePath.hasPrefix("\(collapsedFolder.relativePath)/")
        }
    }
}

@Observable
@MainActor
final class EditorWorkbenchViewModel {
    var aiPrompt: String
    var hoveredChip: String?
    var activeEditorTab: String
    var activeOutputTab: String
    var openDocuments: [EditorWorkbenchDocument]
    var activeDocumentID: String
    var codeColorPalette: EditorCodeColorPalette
    var codeFontSize: Double

    init(
        aiPrompt: String = "",
        hoveredChip: String? = nil,
        activeEditorTab: String = "Main.ascn",
        activeOutputTab: String = "Problems",
        openDocuments: [EditorWorkbenchDocument] = AdaEngineStyleContent.defaultEditorDocuments,
        activeDocumentID: String = "scene:Assets/Scenes/Main.ascn",
        codeColorPalette: EditorCodeColorPalette = .dark,
        codeFontSize: Double = 12
    ) {
        self.aiPrompt = aiPrompt
        self.hoveredChip = hoveredChip
        self.activeEditorTab = activeEditorTab
        self.activeOutputTab = activeOutputTab
        self.openDocuments = openDocuments
        self.activeDocumentID = activeDocumentID
        self.codeColorPalette = codeColorPalette
        self.codeFontSize = codeFontSize
    }

    var aiPromptBinding: Binding<String> {
        Binding(get: { self.aiPrompt }, set: { self.aiPrompt = $0 })
    }

    var activeDocument: EditorWorkbenchDocument? {
        openDocuments.first { $0.id == activeDocumentID }
    }

    func open(_ document: EditorWorkbenchDocument) {
        if let index = openDocuments.firstIndex(where: { $0.id == document.id }) {
            openDocuments[index] = document
        } else {
            openDocuments.append(document)
        }

        selectDocument(id: document.id)
    }

    func selectDocument(id: String) {
        guard let document = openDocuments.first(where: { $0.id == id }) else {
            return
        }

        activeDocumentID = document.id
        activeEditorTab = document.title
    }

    func increaseCodeFontSize() {
        codeFontSize = min(codeFontSize + 1, 28)
    }

    func decreaseCodeFontSize() {
        codeFontSize = max(codeFontSize - 1, 8)
    }

    func resetCodeFontSize() {
        codeFontSize = 12
    }

    func sceneLines(for document: EditorSceneDocument) -> [String] {
        let lines = document.content.components(separatedBy: .newlines)
        return lines.isEmpty ? [""] : lines
    }

    func sceneLineBinding(documentID: String, lineIndex: Int) -> Binding<String> {
        Binding(
            get: {
                guard
                    let document = self.sceneDocument(id: documentID),
                    self.sceneLines(for: document).indices.contains(lineIndex)
                else {
                    return ""
                }

                return self.sceneLines(for: document)[lineIndex]
            },
            set: { newValue in
                self.updateSceneLine(documentID: documentID, lineIndex: lineIndex, value: newValue)
            }
        )
    }

    func textDocumentBinding(documentID: String) -> Binding<String> {
        Binding(
            get: {
                self.textDocument(id: documentID)?.content ?? ""
            },
            set: { newValue in
                self.updateTextDocument(id: documentID) { document in
                    document.content = newValue
                    document.errorMessage = nil
                }
            }
        )
    }

    func appendSceneLine(documentID: String) {
        updateSceneDocument(id: documentID) { document in
            document.content += document.content.hasSuffix("\n") ? "" : "\n"
            document.content += "  "
            document.isDirty = true
            document.statusMessage = "Edited"
        }
    }

    func saveSceneDocument(id documentID: String) {
        updateSceneDocument(id: documentID) { document in
            guard let absolutePath = document.absolutePath else {
                document.statusMessage = "Sample scene cannot be saved"
                return
            }

            do {
                try document.content.write(to: URL(fileURLWithPath: absolutePath), atomically: true, encoding: .utf8)
                document.isDirty = false
                document.errorMessage = nil
                document.statusMessage = "Saved"
            } catch {
                document.statusMessage = "Save failed"
                document.errorMessage = error.localizedDescription
            }
        }
    }

    private func sceneDocument(id documentID: String) -> EditorSceneDocument? {
        guard case .scene(let document)? = openDocuments.first(where: { $0.id == documentID }) else {
            return nil
        }

        return document
    }

    private func textDocument(id documentID: String) -> EditorTextDocument? {
        guard case .text(let document)? = openDocuments.first(where: { $0.id == documentID }) else {
            return nil
        }

        return document
    }

    func updateSceneLine(documentID: String, lineIndex: Int, value: String) {
        updateSceneDocument(id: documentID) { document in
            var lines = document.content.components(separatedBy: .newlines)
            guard lines.indices.contains(lineIndex) else {
                return
            }

            lines[lineIndex] = value
            document.content = lines.joined(separator: "\n")
            document.isDirty = true
            document.statusMessage = "Edited"
            document.errorMessage = nil
        }
    }

    private func updateSceneDocument(id documentID: String, update: (inout EditorSceneDocument) -> Void) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        guard case .scene(var document) = openDocuments[index] else {
            return
        }

        update(&document)
        openDocuments[index] = .scene(document)
    }

    private func updateTextDocument(id documentID: String, update: (inout EditorTextDocument) -> Void) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        guard case .text(var document) = openDocuments[index] else {
            return
        }

        update(&document)
        openDocuments[index] = .text(document)
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
        project: EditorProjectReference? = nil,
        fileManager: FileManager = .default,
        toolbar: EditorToolbarViewModel = EditorToolbarViewModel(),
        toolStrip: EditorToolStripViewModel = EditorToolStripViewModel(),
        projectSidebar: EditorProjectSidebarViewModel? = nil,
        workbench: EditorWorkbenchViewModel = EditorWorkbenchViewModel(),
        inspectorSidebar: EditorInspectorSidebarViewModel = EditorInspectorSidebarViewModel(),
        footer: EditorFooterViewModel = EditorFooterViewModel(),
        activeOutputTab: String = "Problems",
        showsDebugOverlay: Bool = false
    ) {
        self.toolbar = toolbar
        self.toolStrip = toolStrip
        self.projectSidebar = projectSidebar ?? EditorProjectSidebarViewModel(items: Self.projectTreeItems(for: project, fileManager: fileManager))
        self.workbench = workbench
        self.inspectorSidebar = inspectorSidebar
        self.activeOutputTab = activeOutputTab
        self.footer = footer
        self.showsDebugOverlay = showsDebugOverlay
    }

    func toggleDebugOverlay() {
        showsDebugOverlay.toggle()
    }

    func openProjectItem(_ item: EditorProjectSidebarViewModel.Item) {
        if item.isFolder {
            projectSidebar.toggleFolder(item)
            return
        }

        projectSidebar.select(item)
        let document = Self.document(for: item)
        workbench.open(document)

        if case .scene = document {
            toolbar.sceneName = URL(fileURLWithPath: item.title).deletingPathExtension().lastPathComponent
        }
    }

    private static func projectTreeItems(for project: EditorProjectReference?, fileManager: FileManager) -> [EditorProjectSidebarViewModel.Item] {
        guard let project else {
            return EditorProjectSidebarViewModel().items
        }

        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        let items = buildProjectTreeItems(at: projectURL, fileManager: fileManager)
        return items.isEmpty ? EditorProjectSidebarViewModel().items : items
    }

    private static func document(for item: EditorProjectSidebarViewModel.Item) -> EditorWorkbenchDocument {
        switch item.kind {
        case .scene:
            let content = sceneFileContent(for: item)
            return .scene(
                EditorSceneDocument(
                    id: "scene:\(item.relativePath)",
                    title: item.title,
                    relativePath: item.relativePath,
                    absolutePath: absoluteFilePath(from: item.id),
                    content: content.value,
                    errorMessage: content.errorMessage,
                    isDirty: false,
                    statusMessage: content.errorMessage == nil ? "Loaded" : nil
                )
            )
        case .text(let language):
            let content = textFileContent(for: item)
            return .text(
                EditorTextDocument(
                    id: "text:\(item.relativePath)",
                    title: item.title,
                    relativePath: item.relativePath,
                    language: language,
                    content: content.value,
                    errorMessage: content.errorMessage
                )
            )
        case .folder, .unsupported:
            return .text(
                EditorTextDocument(
                    id: "unsupported:\(item.relativePath)",
                    title: item.title,
                    relativePath: item.relativePath,
                    language: .plainText,
                    content: "Preview is not available for this file.",
                    errorMessage: nil
                )
            )
        }
    }

    private static func textFileContent(for item: EditorProjectSidebarViewModel.Item) -> (value: String, errorMessage: String?) {
        if let sample = AdaEngineStyleContent.sampleTextDocuments[item.relativePath] {
            return (sample, nil)
        }

        let url = URL(fileURLWithPath: item.id, isDirectory: false)

        do {
            return (try String(contentsOf: url, encoding: .utf8), nil)
        } catch {
            return ("", error.localizedDescription)
        }
    }

    private static func sceneFileContent(for item: EditorProjectSidebarViewModel.Item) -> (value: String, errorMessage: String?) {
        guard let absolutePath = absoluteFilePath(from: item.id) else {
            return (SceneDocumentFormat.defaultSceneYAML(projectName: item.title), nil)
        }

        do {
            return (try String(contentsOf: URL(fileURLWithPath: absolutePath), encoding: .utf8), nil)
        } catch {
            return ("", error.localizedDescription)
        }
    }

    private static func absoluteFilePath(from path: String) -> String? {
        path.hasPrefix("/") ? path : nil
    }

    private static func buildProjectTreeItems(at projectURL: URL, fileManager: FileManager) -> [EditorProjectSidebarViewModel.Item] {
        let rootEntries = ["Sources", "Assets"]
        var items: [EditorProjectSidebarViewModel.Item] = []

        for entry in rootEntries {
            let url = projectURL.appendingPathComponent(entry)
            guard fileManager.fileExists(atPath: url.path), !shouldSkipProjectTreeURL(url) else {
                continue
            }

            appendProjectTreeItems(
                url: url,
                projectURL: projectURL,
                level: 0,
                fileManager: fileManager,
                items: &items
            )
        }

        if !items.contains(where: { $0.isActive }), let firstSelectableIndex = items.firstIndex(where: { !$0.isFolder }) {
            items[firstSelectableIndex].isActive = true
        }

        return items
    }

    private static func appendProjectTreeItems(
        url: URL,
        projectURL: URL,
        level: Int,
        fileManager: FileManager,
        items: inout [EditorProjectSidebarViewModel.Item]
    ) {
        guard items.count < 300 else {
            return
        }

        let isDirectory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let relativePath = relativePath(for: url, projectURL: projectURL)
        let kind = fileKind(for: url, isDirectory: isDirectory)

        items.append(
            EditorProjectSidebarViewModel.Item(
                id: url.path,
                disclosure: isDirectory ? "▾" : "",
                icon: "▱",
                title: url.lastPathComponent,
                relativePath: relativePath,
                level: level,
                isActive: false,
                isFolder: isDirectory,
                kind: kind
            )
        )

        guard isDirectory, level < 4 else {
            return
        }

        let childURLs = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        for childURL in childURLs.sorted(by: projectTreeSort) where !shouldSkipProjectTreeURL(childURL) {
            appendProjectTreeItems(
                url: childURL,
                projectURL: projectURL,
                level: level + 1,
                fileManager: fileManager,
                items: &items
            )
        }
    }

    private static func fileKind(for url: URL, isDirectory: Bool) -> EditorProjectFileKind {
        if isDirectory {
            return .folder
        }

        if SceneDocumentFormat.isSceneFile(url) {
            return .scene
        }

        if isTextFile(url) {
            return .text(EditorSourceLanguage.detect(fileName: url.lastPathComponent))
        }

        return .unsupported
    }

    private static func isTextFile(_ url: URL) -> Bool {
        let textExtensions: Set<String> = [
            "ada", "c", "cc", "cpp", "cxx", "frag", "glsl", "h", "hpp", "hxx", "json", "md", "markdown",
            "ascn", "metal", "plist", "scn", "scene", "shader", "swift", "toml", "txt", "vert", "xml", "yaml", "yml"
        ]
        let lowercasedName = url.lastPathComponent.lowercased()

        return lowercasedName == "package.swift"
            || lowercasedName == "readme"
            || textExtensions.contains(url.pathExtension.lowercased())
    }

    private static func relativePath(for url: URL, projectURL: URL) -> String {
        let projectPath = projectURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path

        guard path.hasPrefix(projectPath) else {
            return url.lastPathComponent
        }

        let startIndex = path.index(path.startIndex, offsetBy: projectPath.count)
        return String(path[startIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func projectTreeSort(lhs: URL, rhs: URL) -> Bool {
        let lhsIsDirectory = (try? lhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        let rhsIsDirectory = (try? rhs.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true

        if lhsIsDirectory != rhsIsDirectory {
            return lhsIsDirectory
        }

        return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
    }

    private static func shouldSkipProjectTreeURL(_ url: URL) -> Bool {
        let skippedNames: Set<String> = [".ada", ".build", ".git", ".swiftpm", "DerivedData", "Package.resolved", "Package.swift"]
        return skippedNames.contains(url.lastPathComponent)
    }
}
