@_spi(AdaEngine) import AdaEngine
import AdaPackageManifestTool
import Foundation
import Observation

struct EditorToolStripItem: Equatable, Sendable {
    var identifier: String
    var title: String
    var icon: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension EditorTextDocument {
    var fileURL: URL? {
        absolutePath.map { URL(fileURLWithPath: $0, isDirectory: false) }
    }
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
    case image
    case audio
    case genericAsset
    case unsupported
}

enum EditorNewFileKind: String, CaseIterable, Hashable, Sendable {
    case scene
    case script
    case swift
    case plainText

    var title: String {
        switch self {
        case .scene:
            "Scene"
        case .script:
            "Ada Script"
        case .swift:
            "Swift"
        case .plainText:
            "Plain Text"
        }
    }

    var detail: String {
        switch self {
        case .scene:
            "AdaEngine scene"
        case .script:
            "Gravity script"
        case .swift:
            "Swift source file"
        case .plainText:
            "Unformatted text"
        }
    }

    var fileExtension: String {
        switch self {
        case .scene:
            SceneDocumentFormat.canonicalExtension
        case .script:
            "ada"
        case .swift:
            "swift"
        case .plainText:
            "txt"
        }
    }

    func initialContent(fileName: String) -> String {
        switch self {
        case .scene:
            return SceneDocumentFormat.defaultSceneYAML(
                projectName: URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            )
        case .script:
            let typeName = gravityTypeIdentifier(
                URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
            )
            return """
            // \(fileName)

            @system(scheduler: "update")
            class \(typeName)System {
                func update(context) {
                }
            }
            """
        case .swift:
            return "import AdaEngine\n\n"
        case .plainText:
            return ""
        }
    }

    private func gravityTypeIdentifier(_ value: String) -> String {
        let parts = value.split { !$0.isLetter && !$0.isNumber }
        let joined = parts.map { part in
            guard let first = part.first else { return "" }
            return first.uppercased() + part.dropFirst()
        }.joined()
        guard let first = joined.first else { return "Script" }
        return first.isNumber ? "Script\(joined)" : joined
    }
}

enum EditorAssetPreviewKind: String, Equatable, Sendable {
    case image
    case audio
    case generic
}

struct EditorTextDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var absolutePath: String? = nil
    var language: EditorSourceLanguage
    var content: String
    var lastSavedContent: String? = nil
    var isReadOnly: Bool = false
    var errorMessage: String?
    var isDirty: Bool = false
    var statusMessage: String?
    var diagnostics: [EditorDiagnostic] = []
    var semanticTokens: [EditorSemanticToken] = []
    var completionItems: [EditorCompletionItem] = []
    var completionPosition: EditorSourceLocation?
    var symbolHighlights: [EditorSourceRange] = []
    var sourceHoverRange: EditorSourceRange?
    var sourceHoverDescription: String?
    var focusedRange: EditorSourceRange?
    var selectionRange: EditorSourceRange?
    var selectedText: String?
}

struct EditorSceneDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var absolutePath: String?
    var content: String
    var lastSavedContent: String? = nil
    var isReadOnly: Bool = false
    var sceneModel: EditorSceneModel?
    var errorMessage: String?
    var isDirty: Bool
    var statusMessage: String?
    var loadSummary: EditorSceneLoadSummary
}

struct EditorAssetDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var absolutePath: String?
    var assetReference: String?
    var kind: EditorAssetPreviewKind
    var fileExtension: String
    var byteCount: Int64?
    var modifiedAt: Date?
    var errorMessage: String?
}

enum EditorWorkbenchDocument: Equatable, Sendable {
    case scene(EditorSceneDocument)
    case text(EditorTextDocument)
    case asset(EditorAssetDocument)

    var id: String {
        switch self {
        case .scene(let document):
            document.id
        case .text(let document):
            document.id
        case .asset(let document):
            document.id
        }
    }

    var title: String {
        switch self {
        case .scene(let document):
            document.title
        case .text(let document):
            document.title
        case .asset(let document):
            document.title
        }
    }

    var relativePath: String {
        switch self {
        case .scene(let document):
            document.relativePath
        case .text(let document):
            document.relativePath
        case .asset(let document):
            document.relativePath
        }
    }

    var absolutePath: String? {
        switch self {
        case .scene(let document):
            document.absolutePath
        case .text(let document):
            document.absolutePath
        case .asset(let document):
            document.absolutePath
        }
    }

    var isDirty: Bool {
        switch self {
        case .scene(let document):
            document.isDirty
        case .text(let document):
            document.isDirty
        case .asset:
            false
        }
    }
}

enum EditorWorkspaceStatus: Equatable, Sendable {
    case idle
    case resolving
    case indexing
    case preparing(SwiftPMWorkspaceProgress)
    case ready
    case running(String)
    case failed(String)
    case cancelled

    var title: String {
        switch self {
        case .idle:
            "Idle"
        case .resolving:
            "Resolving"
        case .indexing:
            "Indexing"
        case .preparing(let progress):
            progress.progressText
        case .ready:
            "Ready"
        case .running(let command):
            "Running \(command)"
        case .failed:
            "Failed"
        case .cancelled:
            "Cancelled"
        }
    }
}

enum EditorPlayModeState: Equatable, Sendable {
    case editing
    case playing(sceneDocumentID: String, title: String)
    case failed(String)

    var isPlaying: Bool {
        if case .playing = self {
            return true
        }

        return false
    }
}

struct EditorWorkspaceLogLine: Equatable, Sendable, Identifiable {
    static let maximumTextLength = 2_048

    let id: String
    let text: String

    init(id: String = UUID().uuidString, text: String) {
        self.id = id

        let truncationIndex = text.index(
            text.startIndex,
            offsetBy: Self.maximumTextLength,
            limitedBy: text.endIndex
        )
        if let truncationIndex, truncationIndex != text.endIndex {
            self.text = "\(text[..<truncationIndex])… [truncated]"
        } else {
            self.text = text
        }
    }
}

enum EditorWorkspaceLogBuffer {
    static let maximumLineCount = 400

    static func appending(
        _ textLines: [String],
        to existingLines: [EditorWorkspaceLogLine]
    ) -> [EditorWorkspaceLogLine] {
        guard !textLines.isEmpty else {
            return existingLines
        }

        let retainedExistingCount = max(0, maximumLineCount - textLines.count)
        var result = Array(existingLines.suffix(retainedExistingCount))
        result.append(contentsOf: textLines.suffix(maximumLineCount).map { EditorWorkspaceLogLine(text: $0) })
        return result
    }
}

@MainActor
enum EditorPreviewStatus {
    case hidden
    case unavailable(String)
    case available([EditorPreviewDeclaration])
    case building(EditorPreviewDeclaration, String)
    case loaded(EditorPreviewDeclaration, UIView)
    case failed(EditorPreviewDeclaration?, String, Bool)
}

@Observable
@MainActor
final class EditorToolbarViewModel {
    var searchText: String
    var sceneName: String
    var searchableItems: [EditorProjectSidebarViewModel.Item]
    var searchScopeRelativePath: String?

    init(
        searchText: String = "",
        sceneName: String = "main_scene",
        searchableItems: [EditorProjectSidebarViewModel.Item] = [],
        searchScopeRelativePath: String? = nil
    ) {
        self.searchText = searchText
        self.sceneName = sceneName
        self.searchableItems = searchableItems
        self.searchScopeRelativePath = searchScopeRelativePath
    }

    var searchTextBinding: Binding<String> {
        Binding(get: { self.searchText }, set: { self.searchText = $0 })
    }

    var searchPrompt: String {
        guard let searchScopeRelativePath else {
            return "Search Project Files"
        }
        return "Search in \(searchScopeRelativePath)"
    }

    var searchResults: [EditorProjectSidebarViewModel.Item] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return []
        }

        let scopedItems = searchableItems.filter { item in
            guard !item.isFolder else {
                return false
            }
            guard let searchScopeRelativePath else {
                return true
            }
            return item.relativePath.hasPrefix("\(searchScopeRelativePath)/")
        }

        return scopedItems
            .filter { item in
                item.title.localizedCaseInsensitiveContains(query)
                    || item.relativePath.localizedCaseInsensitiveContains(query)
            }
            .sorted { lhs, rhs in
                let lhsStartsWithQuery = lhs.title.lowercased().hasPrefix(query.lowercased())
                let rhsStartsWithQuery = rhs.title.lowercased().hasPrefix(query.lowercased())
                if lhsStartsWithQuery != rhsStartsWithQuery {
                    return lhsStartsWithQuery
                }
                return lhs.relativePath.localizedStandardCompare(rhs.relativePath) == .orderedAscending
            }
            .prefix(12)
            .map { $0 }
    }

    func search(in item: EditorProjectSidebarViewModel.Item?) {
        searchScopeRelativePath = item?.relativePath
        searchText = ""
    }

    func clearSearch() {
        searchText = ""
        searchScopeRelativePath = nil
    }
}

@Observable
@MainActor
final class EditorToolStripViewModel {
    var activeLeftTopTool: String
    var activeLeftBottomTool: String
    var activeRightTool: String
    var leftTopTools: [EditorToolStripItem]
    var leftBottomTools: [EditorToolStripItem]
    var rightTools: [EditorToolStripItem]

    init(
        activeLeftTopTool: String = "fileTree",
        activeLeftBottomTool: String = "logs",
        activeRightTool: String = "agentChat",
        leftTopTools: [EditorToolStripItem] = AdaEngineStyleContent.leftTopSidebarTools,
        leftBottomTools: [EditorToolStripItem] = AdaEngineStyleContent.leftBottomSidebarTools,
        rightTools: [EditorToolStripItem] = AdaEngineStyleContent.rightSidebarTools
    ) {
        self.activeLeftTopTool = activeLeftTopTool
        self.activeLeftBottomTool = activeLeftBottomTool
        self.activeRightTool = activeRightTool
        self.leftTopTools = leftTopTools
        self.leftBottomTools = leftBottomTools
        self.rightTools = rightTools
    }

    func selectLeftTopTool(_ item: EditorToolStripItem) {
        activeLeftTopTool = item.identifier
    }

    func selectLeftBottomTool(_ item: EditorToolStripItem) {
        activeLeftBottomTool = item.identifier
    }

    func selectRightTool(_ item: EditorToolStripItem) {
        activeRightTool = item.identifier
    }
}

@Observable
@MainActor
final class EditorProjectSidebarViewModel {
    enum DisplayMode: String, CaseIterable {
        case targets
        case files

        var title: String {
            switch self {
            case .targets:
                "Targets"
            case .files:
                "Files"
            }
        }
    }

    struct Item: Equatable {
        var id: String
        var disclosure: String
        var icon: String
        var title: String
        var relativePath: String
        var level: Int
        var isActive: Bool
        var isFolder: Bool
        var isSymbolicLink: Bool = false
        var kind: EditorProjectFileKind
        var assetRoot: String? = nil
    }

    var items: [Item]
    var collapsedFolderIDs: Set<String>
    var displayMode: DisplayMode
    var isDisplayModeMenuPresented: Bool

    var visibleItems: [Item] {
        displayedItems.filter { !isHiddenByCollapsedFolder($0) }
    }

    var selectedItem: Item? {
        items.first(where: \.isActive)
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
    ], collapsedFolderIDs: Set<String> = [], displayMode: DisplayMode = .targets, isDisplayModeMenuPresented: Bool = false) {
        self.items = items
        self.collapsedFolderIDs = collapsedFolderIDs
        self.displayMode = displayMode
        self.isDisplayModeMenuPresented = isDisplayModeMenuPresented
    }

    private var displayedItems: [Item] {
        switch displayMode {
        case .files:
            items
        case .targets:
            targetItems
        }
    }

    private var targetItems: [Item] {
        let targetRoots = items.filter { item in
            item.assetRoot == item.relativePath || isSourceTarget(item)
        }

        return targetRoots.flatMap { root in
            items.compactMap { item in
                guard item.relativePath == root.relativePath || item.relativePath.hasPrefix("\(root.relativePath)/") else {
                    return nil
                }

                var targetItem = item
                targetItem.level -= root.level
                return targetItem
            }
        }
    }

    func select(_ selectedItem: Item) {
        for index in items.indices {
            items[index].isActive = items[index].id == selectedItem.id
        }
    }

    func selectDisplayMode(_ displayMode: DisplayMode) {
        self.displayMode = displayMode
        isDisplayModeMenuPresented = false
    }

    func toggleDisplayModeMenu() {
        isDisplayModeMenuPresented.toggle()
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

    func expandAll() {
        collapsedFolderIDs.removeAll()
    }

    func collapseAll() {
        collapsedFolderIDs = Set(items.lazy.filter(\.isFolder).map(\.id))
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

    private func isSourceTarget(_ item: Item) -> Bool {
        item.isFolder && item.level == 1 && item.relativePath.hasPrefix("Sources/")
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
    var previewStatus: EditorPreviewStatus
    var selectedPreviewID: String?

    @ObservationIgnored
    private var onActiveDocumentChanged: (() -> Void)?
    @ObservationIgnored
    private var onActiveDocumentWillChange: (() -> Void)?
    @ObservationIgnored
    private var onDocumentEdited: ((String) -> Void)?
    @ObservationIgnored
    private var navigationHistory: [String]
    @ObservationIgnored
    private var navigationHistoryIndex: Int

    init(
        aiPrompt: String = "",
        hoveredChip: String? = nil,
        activeEditorTab: String = "Main.ascn",
        activeOutputTab: String = "Problems",
        openDocuments: [EditorWorkbenchDocument] = AdaEngineStyleContent.defaultEditorDocuments,
        activeDocumentID: String = "scene:Assets/Scenes/Main.ascn",
        codeColorPalette: EditorCodeColorPalette = .dark,
        codeFontSize: Double = 12,
        previewStatus: EditorPreviewStatus = .hidden,
        selectedPreviewID: String? = nil
    ) {
        self.aiPrompt = aiPrompt
        self.hoveredChip = hoveredChip
        self.activeEditorTab = activeEditorTab
        self.activeOutputTab = activeOutputTab
        self.openDocuments = openDocuments
        self.activeDocumentID = activeDocumentID
        self.codeColorPalette = codeColorPalette
        self.codeFontSize = codeFontSize
        self.previewStatus = previewStatus
        self.selectedPreviewID = selectedPreviewID
        if openDocuments.contains(where: { $0.id == activeDocumentID }) {
            self.navigationHistory = [activeDocumentID]
            self.navigationHistoryIndex = 0
        } else {
            self.navigationHistory = []
            self.navigationHistoryIndex = -1
        }
    }

    var aiPromptBinding: Binding<String> {
        Binding(get: { self.aiPrompt }, set: { self.aiPrompt = $0 })
    }

    func setActiveDocumentChangedHandler(_ handler: @escaping () -> Void) {
        onActiveDocumentChanged = handler
    }

    func setActiveDocumentWillChangeHandler(_ handler: @escaping () -> Void) {
        onActiveDocumentWillChange = handler
    }

    func setDocumentEditedHandler(_ handler: @escaping (String) -> Void) {
        onDocumentEdited = handler
    }

    var activeDocument: EditorWorkbenchDocument? {
        openDocuments.first { $0.id == activeDocumentID }
    }

    var activeSceneDocument: EditorSceneDocument? {
        guard case .scene(let document)? = activeDocument else {
            return nil
        }

        return document
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
        selectDocument(id: id, recordsNavigation: true)
    }

    @discardableResult
    func navigateBack() -> Bool {
        navigateHistory(step: -1)
    }

    @discardableResult
    func navigateForward() -> Bool {
        navigateHistory(step: 1)
    }

    private func selectDocument(id: String, recordsNavigation: Bool) {
        guard let document = openDocuments.first(where: { $0.id == id }) else {
            return
        }

        if activeDocumentID != document.id {
            onActiveDocumentWillChange?()
            if recordsNavigation {
                recordNavigation(to: document.id)
            }
            activeDocumentID = document.id
        }

        activeEditorTab = document.title
        onActiveDocumentChanged?()
    }

    private func recordNavigation(to documentID: String) {
        if navigationHistory.indices.contains(navigationHistoryIndex), navigationHistory[navigationHistoryIndex] == documentID {
            return
        }

        let firstForwardIndex = navigationHistoryIndex + 1
        if navigationHistory.indices.contains(firstForwardIndex) {
            navigationHistory.removeSubrange(firstForwardIndex...)
        }
        navigationHistory.append(documentID)
        navigationHistoryIndex = navigationHistory.count - 1
    }

    private func navigateHistory(step: Int) -> Bool {
        var candidateIndex = navigationHistoryIndex + step
        while navigationHistory.indices.contains(candidateIndex) {
            let documentID = navigationHistory[candidateIndex]
            if documentID != activeDocumentID, openDocuments.contains(where: { $0.id == documentID }) {
                navigationHistoryIndex = candidateIndex
                selectDocument(id: documentID, recordsNavigation: false)
                return true
            }
            candidateIndex += step
        }
        return false
    }

    func closeDocument(id documentID: String) {
        guard let closingIndex = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        let closingDocument = openDocuments[closingIndex]
        if closingDocument.isDirty, !saveDocument(closingDocument) {
            return
        }

        let wasActiveDocument = activeDocumentID == documentID
        if wasActiveDocument {
            onActiveDocumentWillChange?()
        }
        openDocuments.remove(at: closingIndex)

        guard wasActiveDocument else {
            return
        }

        guard !openDocuments.isEmpty else {
            activeDocumentID = ""
            activeEditorTab = ""
            onActiveDocumentChanged?()
            return
        }

        let nextIndex = min(closingIndex, openDocuments.count - 1)
        selectDocument(id: openDocuments[nextIndex].id, recordsNavigation: false)
    }

    func closeOtherDocuments(keeping documentID: String) {
        closeDocuments(withIDs: openDocuments.lazy.filter { $0.id != documentID }.map(\.id))
    }

    func closeDocumentsToLeft(of documentID: String) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }
        closeDocuments(withIDs: openDocuments[..<index].map(\.id))
    }

    func closeDocumentsToRight(of documentID: String) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }
        closeDocuments(withIDs: openDocuments[openDocuments.index(after: index)...].map(\.id))
    }

    func closeCleanDocuments() {
        closeDocuments(withIDs: openDocuments.lazy.filter { !$0.isDirty }.map(\.id))
    }

    func closeAllDocuments() {
        closeDocuments(withIDs: openDocuments.map(\.id))
    }

    private func closeDocuments<S: Sequence>(withIDs documentIDs: S) where S.Element == String {
        for documentID in documentIDs {
            closeDocument(id: documentID)
        }
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
                guard self.textDocument(id: documentID)?.isReadOnly == false else {
                    return
                }
                self.updateTextDocument(id: documentID) { document in
                    document.content = newValue
                    document.errorMessage = nil
                    document.isDirty = true
                    document.statusMessage = "Edited"
                }
            }
        )
    }

    @discardableResult
    func saveActiveDocument() -> Bool {
        guard let activeDocument else {
            return false
        }

        return saveDocument(activeDocument)
    }

    @discardableResult
    func saveAllDocuments() -> Bool {
        var didSaveAll = true
        for document in openDocuments where document.isDirty {
            if !saveDocument(document) {
                didSaveAll = false
            }
        }
        return didSaveAll
    }

    @discardableResult
    func saveActiveDocumentIfNeeded() -> Bool {
        guard let activeDocument, activeDocument.isDirty else {
            return false
        }

        return saveDocument(activeDocument)
    }

    var activeDocumentSaveFailureDescription: String? {
        switch activeDocument {
        case .scene(let document)?:
            document.statusMessage ?? document.errorMessage
        case .text(let document)?:
            document.statusMessage ?? document.errorMessage
        case .asset?:
            "assets cannot be saved from the code editor"
        case nil:
            nil
        }
    }

    @discardableResult
    func saveDocument(_ document: EditorWorkbenchDocument) -> Bool {
        switch document {
        case .scene(let document):
            return saveSceneDocument(id: document.id)
        case .text(let document):
            return saveTextDocument(id: document.id)
        case .asset:
            return false
        }
    }

    func appendSceneLine(documentID: String) {
        updateSceneDocument(id: documentID) { document in
            guard !document.isReadOnly else {
                document.statusMessage = "Edit blocked: file is read-only"
                return
            }
            document.content += document.content.hasSuffix("\n") ? "" : "\n"
            document.content += "  "
            document.isDirty = true
            document.statusMessage = "Edited"
            document.loadSummary = EditorSceneFileLoader.summary(from: document.content)
            document.sceneModel = EditorSceneFileLoader.model(from: document.content)
        }
    }

    @discardableResult
    func saveSceneDocument(id documentID: String) -> Bool {
        var didSave = false
        updateSceneDocument(id: documentID) { document in
            guard !document.isReadOnly else {
                document.statusMessage = "Save blocked: file is read-only"
                document.errorMessage = document.errorMessage ?? "Symbolic-link scene files are read-only in the editor."
                return
            }
            guard let absolutePath = document.absolutePath else {
                document.statusMessage = "Sample scene cannot be saved"
                return
            }

            do {
                let sceneModel = try EditorSceneModel.decode(from: document.content)
                if let lastSavedContent = document.lastSavedContent {
                    let currentDiskContent = try String(contentsOf: URL(fileURLWithPath: absolutePath), encoding: .utf8)
                    guard currentDiskContent == lastSavedContent else {
                        document.statusMessage = "Save blocked: file changed on disk"
                        document.errorMessage = "Reload the scene before overwriting external changes."
                        return
                    }
                }

                try document.content.write(to: URL(fileURLWithPath: absolutePath), atomically: true, encoding: .utf8)
                document.sceneModel = sceneModel
                document.loadSummary = EditorSceneFileLoader.summary(from: document.content)
                document.lastSavedContent = document.content
                document.isDirty = false
                document.errorMessage = nil
                document.statusMessage = "Saved"
                didSave = true
            } catch {
                document.statusMessage = "Save blocked"
                document.errorMessage = error.localizedDescription
            }
        }
        return didSave
    }

    @discardableResult
    func saveTextDocument(id documentID: String) -> Bool {
        var didSave = false
        updateTextDocument(id: documentID) { document in
            guard !document.isReadOnly else {
                document.statusMessage = "Save blocked: file is read-only"
                document.errorMessage = document.errorMessage ?? "The file could not be decoded as UTF-8 and will not be overwritten."
                return
            }
            guard let absolutePath = document.absolutePath else {
                document.statusMessage = "Sample file cannot be saved"
                return
            }

            do {
                if let lastSavedContent = document.lastSavedContent {
                    let currentDiskContent = try String(contentsOf: URL(fileURLWithPath: absolutePath, isDirectory: false), encoding: .utf8)
                    guard currentDiskContent == lastSavedContent else {
                        document.statusMessage = "Save blocked: file changed on disk"
                        document.errorMessage = "Reload the file before overwriting external changes."
                        return
                    }
                }

                try document.content.write(to: URL(fileURLWithPath: absolutePath, isDirectory: false), atomically: true, encoding: .utf8)
                document.lastSavedContent = document.content
                document.isDirty = false
                document.errorMessage = nil
                document.statusMessage = "Saved"
                didSave = true
            } catch {
                document.statusMessage = "Save failed: \(error.localizedDescription)"
                document.errorMessage = error.localizedDescription
            }
        }
        return didSave
    }

    func replaceSceneDocument(_ document: EditorSceneDocument) {
        guard let index = openDocuments.firstIndex(where: { $0.id == document.id }) else {
            return
        }

        guard case .scene(var previousDocument) = openDocuments[index] else {
            return
        }
        guard !previousDocument.isReadOnly else {
            previousDocument.statusMessage = "Edit blocked: file is read-only"
            previousDocument.errorMessage = previousDocument.errorMessage ?? "Symbolic-link scene files are read-only in the editor."
            openDocuments[index] = .scene(previousDocument)
            notifyActiveDocumentChangedIfNeeded(documentID: document.id)
            return
        }

        openDocuments[index] = .scene(document)
        notifyActiveDocumentChangedIfNeeded(documentID: document.id)
        if document.isDirty,
           document.content != previousDocument.content || document.sceneModel != previousDocument.sceneModel || !previousDocument.isDirty {
            onDocumentEdited?(document.id)
        }
    }

    func addEntity(to documentID: String) {
        updateSceneModelDocument(id: documentID, status: "Entity added") { model in
            _ = model.addEntity()
        }
    }

    func selectSceneEntity(documentID: String, entityID: String?) {
        updateSceneModelDocument(id: documentID, status: "Selected") { model in
            model.selectEntity(entityID)
        }
    }

    func toggleSceneEntityExpanded(documentID: String, entityID: String) {
        updateSceneModelDocument(id: documentID, status: "Hierarchy updated") { model in
            model.toggleEntityExpanded(entityID)
        }
    }

    func addComponent(typeName: String, toSelectedEntityIn documentID: String) {
        updateSceneModelDocument(id: documentID, status: "Component added") { model in
            guard let selectedEntityID = model.editor?.selectedEntity else {
                return
            }
            model.addComponent(typeName: typeName, to: selectedEntityID)
        }
    }

    func removeComponent(typeName: String, fromSelectedEntityIn documentID: String) {
        updateSceneModelDocument(id: documentID, status: "Component removed") { model in
            guard let selectedEntityID = model.editor?.selectedEntity else {
                return
            }
            model.removeComponent(typeName: typeName, from: selectedEntityID)
        }
    }

    func updateComponentField(
        typeName: String,
        field: EditorComponentField,
        value: String,
        inSelectedEntityOf documentID: String
    ) {
        updateSceneModelDocument(id: documentID, status: "Edited") { model in
            guard let selectedEntityID = model.editor?.selectedEntity else {
                return
            }
            model.updateField(typeName: typeName, field: field, value: value, in: selectedEntityID)
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
            guard !document.isReadOnly else {
                document.statusMessage = "Edit blocked: file is read-only"
                return
            }
            var lines = document.content.components(separatedBy: .newlines)
            guard lines.indices.contains(lineIndex) else {
                return
            }

            lines[lineIndex] = value
            document.content = lines.joined(separator: "\n")
            document.isDirty = true
            document.statusMessage = "Edited"
            document.errorMessage = nil
            document.loadSummary = EditorSceneFileLoader.summary(from: document.content)
            document.sceneModel = EditorSceneFileLoader.model(from: document.content)
        }
    }

    private func updateSceneModelDocument(id documentID: String, status: String, update: (inout EditorSceneModel) -> Void) {
        updateSceneDocument(id: documentID) { document in
            guard !document.isReadOnly else {
                document.statusMessage = "Edit blocked: file is read-only"
                return
            }
            guard var model = document.sceneModel ?? EditorSceneFileLoader.model(from: document.content) else {
                document.statusMessage = "Scene model unavailable"
                return
            }

            update(&model)

            do {
                document.sceneModel = model
                document.content = try model.encodedYAML()
                document.loadSummary = EditorSceneFileLoader.summary(from: document.content)
                document.isDirty = true
                document.statusMessage = status
                document.errorMessage = nil
            } catch {
                document.statusMessage = "Scene encode failed"
                document.errorMessage = error.localizedDescription
            }
        }
    }

    private func updateSceneDocument(id documentID: String, update: (inout EditorSceneDocument) -> Void) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        guard case .scene(var document) = openDocuments[index] else {
            return
        }

        let previousContent = document.content
        let wasDirty = document.isDirty
        update(&document)
        openDocuments[index] = .scene(document)
        notifyActiveDocumentChangedIfNeeded(documentID: documentID)
        if document.isDirty, document.content != previousContent || !wasDirty {
            onDocumentEdited?(documentID)
        }
    }

    func updateTextDocument(id documentID: String, update: (inout EditorTextDocument) -> Void) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        guard case .text(var document) = openDocuments[index] else {
            return
        }

        let previousContent = document.content
        let wasDirty = document.isDirty
        update(&document)
        openDocuments[index] = .text(document)
        notifyActiveDocumentChangedIfNeeded(documentID: documentID)
        if document.isDirty, document.content != previousContent || !wasDirty {
            onDocumentEdited?(documentID)
        }
    }

    private func notifyActiveDocumentChangedIfNeeded(documentID: String) {
        guard activeDocumentID == documentID else {
            return
        }

        onActiveDocumentChanged?()
    }
}

@Observable
@MainActor
final class EditorInspectorSidebarViewModel {
    struct TransformField: Equatable {
        var field: EditorComponentField
        var value: String

        var label: String { field.label }

        init(field: EditorComponentField, value: String) {
            self.field = field
            self.value = value
        }

        init(label: String, value: String) {
            self.field = EditorComponentField(key: label.lowercased(), label: label, kind: .readOnly, isEditable: false)
            self.value = value
        }
    }

    struct SelectedEntity: Equatable {
        var editorID: String
        var name: String
        var componentNames: [String]
        var transformFields: [TransformField]
        var components: [ComponentSection]
        var addableComponents: [AddableComponent]
        var gizmo: EditorGizmo?
        var hasExplicitGizmo: Bool
    }

    struct ComponentSection: Equatable {
        var typeName: String
        var displayName: String
        var fields: [ComponentField]
        var canRemove: Bool
    }

    struct ComponentField: Equatable {
        var typeName: String
        var field: EditorComponentField
        var value: String
    }

    struct AddableComponent: Equatable {
        var typeName: String
        var displayName: String
        var category: String
    }

    var transformFields: [TransformField]
    var scriptName: String
    var scriptDescription: String
    var selectedEntity: SelectedEntity?

    @ObservationIgnored
    var applyGizmoChange: ((EditorGizmo) -> Void)?
    @ObservationIgnored
    var addEntity: (() -> Void)?
    @ObservationIgnored
    var addComponent: ((String) -> Void)?
    @ObservationIgnored
    var removeComponent: ((String) -> Void)?
    @ObservationIgnored
    var updateComponentField: ((String, EditorComponentField, String) -> Void)?
    @ObservationIgnored
    private var sceneViewportActionOwner: ObjectIdentifier?
    @ObservationIgnored
    private var vectorAxisDrafts: [VectorAxisDraftKey: String] = [:]

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
        self.selectedEntity = nil
    }

    var gizmoNameBinding: Binding<String> {
        Binding(
            get: { self.selectedEntity?.gizmo?.name ?? "" },
            set: { self.updateSelectedGizmo { $0.name = $1 }($0) }
        )
    }

    func selectEntity(_ entity: SelectedEntity?) {
        selectedEntity = entity
        transformFields = entity?.transformFields ?? []
        vectorAxisDrafts.removeAll()
    }

    func setSceneViewportActions(
        owner: AnyObject,
        applyGizmoChange: @escaping (EditorGizmo) -> Void,
        addEntity: @escaping () -> Void,
        addComponent: @escaping (String) -> Void,
        removeComponent: @escaping (String) -> Void,
        updateComponentField: @escaping (String, EditorComponentField, String) -> Void
    ) {
        sceneViewportActionOwner = ObjectIdentifier(owner)
        self.applyGizmoChange = applyGizmoChange
        self.addEntity = addEntity
        self.addComponent = addComponent
        self.removeComponent = removeComponent
        self.updateComponentField = updateComponentField
    }

    func clearSceneViewportActions(owner: AnyObject) {
        guard sceneViewportActionOwner == ObjectIdentifier(owner) else {
            return
        }

        sceneViewportActionOwner = nil
        applyGizmoChange = nil
        addEntity = nil
        addComponent = nil
        removeComponent = nil
        updateComponentField = nil
    }

    func addGizmo() {
        let gizmo = selectedEntity?.gizmo ?? EditorGizmo(name: selectedEntity?.name ?? "Gizmo", kind: .custom)
        updateGizmo(gizmo)
    }

    func addEntityRequested() {
        addEntity?()
    }

    func addComponentRequested(_ typeName: String) {
        addComponent?(typeName)
    }

    func removeComponentRequested(_ typeName: String) {
        removeComponent?(typeName)
    }

    func componentFieldBinding(typeName: String, field: EditorComponentField) -> Binding<String> {
        Binding(
            get: {
                self.componentFieldValue(typeName: typeName, field: field)
            },
            set: { value in
                self.setComponentField(typeName: typeName, field: field, value: value)
            }
        )
    }

    func transformFieldBinding(_ field: TransformField) -> Binding<String> {
        componentFieldBinding(typeName: EditorBuiltInComponentType.transform, field: field.field)
    }

    func componentVectorAxisBinding(typeName: String, field: EditorComponentField, axisIndex: Int) -> Binding<String> {
        Binding(
            get: {
                let draftKey = VectorAxisDraftKey(typeName: typeName, fieldKey: field.key, axisIndex: axisIndex)
                if let draft = self.vectorAxisDrafts[draftKey] {
                    return draft
                }

                let components = self.vectorComponents(
                    from: self.componentFieldValue(typeName: typeName, field: field),
                    count: field.kind.vectorComponentCount
                )
                guard components.indices.contains(axisIndex) else {
                    return ""
                }
                return components[axisIndex]
            },
            set: { value in
                self.setVectorAxis(typeName: typeName, field: field, axisIndex: axisIndex, value: value)
            }
        )
    }

    func transformVectorAxisBinding(field: TransformField, axisIndex: Int) -> Binding<String> {
        componentVectorAxisBinding(typeName: EditorBuiltInComponentType.transform, field: field.field, axisIndex: axisIndex)
    }

    private func componentFieldValue(typeName: String, field: EditorComponentField) -> String {
        selectedEntity?
            .components
            .first { $0.typeName == typeName }?
            .fields
            .first { $0.field.key == field.key }?
            .value ?? ""
    }

    private func setComponentField(typeName: String, field: EditorComponentField, value: String) {
        guard let componentIndex = selectedEntity?.components.firstIndex(where: { $0.typeName == typeName }),
              let fieldIndex = selectedEntity?.components[componentIndex].fields.firstIndex(where: { $0.field.key == field.key }) else {
            return
        }
        selectedEntity?.components[componentIndex].fields[fieldIndex].value = value
        updateComponentField?(typeName, field, value)
    }

    private func setVectorAxis(typeName: String, field: EditorComponentField, axisIndex: Int, value: String) {
        let count = field.kind.vectorComponentCount
        guard axisIndex < count else {
            return
        }

        let draftKey = VectorAxisDraftKey(typeName: typeName, fieldKey: field.key, axisIndex: axisIndex)
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedValue.isEmpty || Double(trimmedValue) == nil {
            vectorAxisDrafts[draftKey] = value
            return
        }

        vectorAxisDrafts[draftKey] = nil
        var components = vectorComponents(from: componentFieldValue(typeName: typeName, field: field), count: count)
        components[axisIndex] = trimmedValue
        setComponentField(typeName: typeName, field: field, value: components.joined(separator: ", "))
    }

    private func vectorComponents(from value: String, count: Int) -> [String] {
        var components = value
            .split { $0 == "," || $0 == " " || $0 == "\t" }
            .map { String($0) }
        if components.count < count {
            components.append(contentsOf: Array(repeating: "0", count: count - components.count))
        }
        return Array(components.prefix(count))
    }

    func toggleGizmoEnabled() {
        updateSelectedGizmo { gizmo, _ in
            gizmo.isEnabled.toggle()
        }("")
    }

    func setGizmoKind(_ kind: EditorGizmoKind) {
        updateSelectedGizmo { gizmo, _ in
            gizmo.kind = kind
        }("")
    }

    private func updateSelectedGizmo(_ update: @escaping (inout EditorGizmo, String) -> Void) -> (String) -> Void {
        { value in
            guard var gizmo = self.selectedEntity?.gizmo else {
                var gizmo = EditorGizmo(name: self.selectedEntity?.name ?? "Gizmo", kind: .custom)
                update(&gizmo, value)
                self.updateGizmo(gizmo)
                return
            }
            update(&gizmo, value)
            self.updateGizmo(gizmo)
        }
    }

    private func updateGizmo(_ gizmo: EditorGizmo) {
        selectedEntity?.gizmo = gizmo
        selectedEntity?.hasExplicitGizmo = true
        applyGizmoChange?(gizmo)
    }
}

private struct VectorAxisDraftKey: Hashable {
    var typeName: String
    var fieldKey: String
    var axisIndex: Int
}

private extension EditorComponentFieldKind {
    var vectorComponentCount: Int {
        switch self {
        case .vector2:
            return 2
        case .vector3:
            return 3
        case .vector4:
            return 4
        default:
            return 0
        }
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

    func setSourceControlFooterTitle(_ title: String) {
        var items = rightItems.filter { !$0.hasPrefix("Git:") }
        items.append(title)
        rightItems = items
    }

    func setWorkspaceFooterTitle(_ title: String) {
        var items = leftItems.filter { !$0.hasPrefix("Workspace:") }
        items.append(title.hasPrefix("Workspace:") ? title : "Workspace: \(title)")
        leftItems = items
    }
}

@Observable
@MainActor
final class EditorSourceControlViewModel {
    var snapshot: GitRepositorySnapshot
    var commitMessage: String
    var newBranchName: String
    var statusMessage: String
    var isRunning: Bool

    init(
        snapshot: GitRepositorySnapshot = .empty,
        commitMessage: String = "",
        newBranchName: String = "",
        statusMessage: String = "Source Control is not loaded.",
        isRunning: Bool = false
    ) {
        self.snapshot = snapshot
        self.commitMessage = commitMessage
        self.newBranchName = newBranchName
        self.statusMessage = statusMessage
        self.isRunning = isRunning
    }

    var commitMessageBinding: Binding<String> {
        Binding(get: { self.commitMessage }, set: { self.commitMessage = $0 })
    }

    var newBranchNameBinding: Binding<String> {
        Binding(get: { self.newBranchName }, set: { self.newBranchName = $0 })
    }

    var trimmedCommitMessage: String {
        commitMessage.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedNewBranchName: String {
        newBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canCommit: Bool {
        !isRunning && !trimmedCommitMessage.isEmpty && !snapshot.stagedFiles.isEmpty
    }

    var canCreateBranch: Bool {
        !isRunning && !trimmedNewBranchName.isEmpty
    }

    var hasChanges: Bool {
        snapshot.hasChanges
    }
}

@Observable
@MainActor
final class EditorViewModel {
    let project: EditorProjectReference?
    var toolbar: EditorToolbarViewModel
    var toolStrip: EditorToolStripViewModel
    var projectSidebar: EditorProjectSidebarViewModel
    var workbench: EditorWorkbenchViewModel
    var inspectorSidebar: EditorInspectorSidebarViewModel
    var agent: EditorAgentViewModel
    var sourceControl: EditorSourceControlViewModel
    var footer: EditorFooterViewModel
    var showsDebugOverlay: UIDebugOverlayMode?
    var activeOutputTab: String
    var workspaceStatus: EditorWorkspaceStatus
    var packageModel: SwiftPackageModel?
    var outputLines: [EditorWorkspaceLogLine]
    var buildActivity: EditorBuildActivity?
    var problems: [EditorDiagnostic]
    var symbolReferences: [EditorSourceReference]
    var selectedRunProduct: String?
    var selectedRunDestination: EditorRunDestination
    var dependencyLocation = ""
    var dependencyRequirement = #"from: "1.0.0""#
    var dependencyStatusMessage = ""
    var projectResourceRootsText = ""
    var projectIncludedFilesText = ""
    var projectExcludedFilesText = ""
    var projectSettingsStatusMessage = ""
    var selectedTestFilter: String
    var playModeState: EditorPlayModeState
    var isNewFileDialogPresented = false
    var newFileKind = EditorNewFileKind.scene
    var newFileName = ""
    var newFileDestinationRelativePath = ""
    var newFileErrorMessage: String?
    var requestedSettingsSection: EditorSettingsSection?
    var settingsPresentationToken = 0
    
    var showLeftPanel = true
    var showRightPanel = false
    var showBottomPanel = false

    @ObservationIgnored
    private let workspaceService: any SwiftPMWorkspaceServicing
    @ObservationIgnored
    private let sourceControlService: any GitRepositoryServicing
    @ObservationIgnored
    private let fileManager: FileManager
    @ObservationIgnored
    private let previewBuilder: EditorPreviewBuilder
    @ObservationIgnored
    private let previewLibrary = EditorPreviewDynamicLibrary()
    @ObservationIgnored
    private var workspaceTask: Task<Void, Never>?
    @ObservationIgnored
    private var sourceControlTask: Task<Void, Never>?
    @ObservationIgnored
    private var previewTask: Task<Void, Never>?
    @ObservationIgnored
    private var completionTask: Task<Void, Never>?
    @ObservationIgnored
    private var autosaveTasks: [String: Task<Void, Never>] = [:]
    @ObservationIgnored
    private let autosaveDelay: Duration
    @ObservationIgnored
    private var didStartEditorSession = false
    @ObservationIgnored
    private var latestSourceHoverKey: String?
    @ObservationIgnored
    private var lastLoggedWorkspaceProgressPhase: SwiftPMWorkspaceBootstrapPhase?
    @ObservationIgnored
    private var pendingWorkspaceStandardOutput = ""
    @ObservationIgnored
    private var pendingWorkspaceStandardError = ""
    @ObservationIgnored
    private var didReceiveStreamingWorkspaceOutput = false

    init(
        project: EditorProjectReference? = nil,
        fileManager: FileManager = .default,
        workspaceService: any SwiftPMWorkspaceServicing = SwiftPMWorkspaceService(),
        sourceControlService: any GitRepositoryServicing = GitRepositoryService(),
        previewBuilder: EditorPreviewBuilder = EditorPreviewBuilder(),
        toolbar: EditorToolbarViewModel = EditorToolbarViewModel(),
        toolStrip: EditorToolStripViewModel = EditorToolStripViewModel(),
        projectSidebar: EditorProjectSidebarViewModel? = nil,
        workbench: EditorWorkbenchViewModel? = nil,
        inspectorSidebar: EditorInspectorSidebarViewModel = EditorInspectorSidebarViewModel(),
        agent: EditorAgentViewModel? = nil,
        sourceControl: EditorSourceControlViewModel = EditorSourceControlViewModel(),
        footer: EditorFooterViewModel = EditorFooterViewModel(),
        activeOutputTab: String = "Problems",
        workspaceStatus: EditorWorkspaceStatus = .idle,
        packageModel: SwiftPackageModel? = nil,
        outputLines: [EditorWorkspaceLogLine]? = nil,
        buildActivity: EditorBuildActivity? = nil,
        problems: [EditorDiagnostic] = [],
        symbolReferences: [EditorSourceReference] = [],
        selectedRunProduct: String? = nil,
        selectedRunDestination: EditorRunDestination? = nil,
        selectedTestFilter: String = "",
        playModeState: EditorPlayModeState = .editing,
        autosaveDelay: Duration = .milliseconds(350)
    ) {
        self.project = project
        self.workspaceService = workspaceService
        self.sourceControlService = sourceControlService
        self.fileManager = fileManager
        self.previewBuilder = previewBuilder
        self.autosaveDelay = autosaveDelay
        self.toolbar = toolbar
        self.toolStrip = toolStrip
        self.projectSidebar = projectSidebar ?? EditorProjectSidebarViewModel(items: Self.projectTreeItems(for: project, fileManager: fileManager))
        self.workbench = workbench ?? Self.defaultWorkbench(for: project)
        self.inspectorSidebar = inspectorSidebar
        self.agent = agent ?? EditorAgentViewModel(project: project, fileManager: fileManager)
        self.sourceControl = sourceControl
        self.activeOutputTab = activeOutputTab
        self.footer = footer
        self.workspaceStatus = workspaceStatus
        self.packageModel = packageModel
        self.outputLines = outputLines ?? (project == nil ? AdaEngineStyleContent.logLines.map { EditorWorkspaceLogLine(text: $0) } : [])
        self.buildActivity = buildActivity
        self.problems = problems
        self.symbolReferences = symbolReferences
        self.selectedRunProduct = selectedRunProduct
        let savedProject = project.flatMap { try? ProjectSystem.loadProject(at: URL(fileURLWithPath: $0.path, isDirectory: true), fileManager: fileManager) }
        self.selectedRunDestination = selectedRunDestination ?? Self.editorRunDestination(from: savedProject?.run.destination ?? .macOS)
        self.projectResourceRootsText = savedProject?.paths.resourceRoots.joined(separator: "\n") ?? ""
        self.projectIncludedFilesText = savedProject?.build.includedFiles.joined(separator: "\n") ?? ""
        self.projectExcludedFilesText = savedProject?.build.excludedFiles.joined(separator: "\n") ?? ""
        self.selectedTestFilter = selectedTestFilter
        self.playModeState = playModeState
        self.toolbar.searchableItems = self.projectSidebar.items
        self.agent.setProjectFileChangedHandler { [weak self] relativePath in
            self?.handleAgentProjectFileChanged(relativePath: relativePath, fileManager: fileManager)
        }
        self.workbench.setActiveDocumentWillChangeHandler { [weak self] in
            self?.saveActiveDocumentIfNeeded()
        }
        self.workbench.setActiveDocumentChangedHandler { [weak self] in
            self?.synchronizeAgentSceneContext()
        }
        self.workbench.setDocumentEditedHandler { [weak self] documentID in
            self?.scheduleAutosave(documentID: documentID)
        }
        synchronizeAgentSceneContext()
    }

    private static func defaultWorkbench(for project: EditorProjectReference?) -> EditorWorkbenchViewModel {
        guard project != nil else {
            return EditorWorkbenchViewModel()
        }

        return EditorWorkbenchViewModel(activeEditorTab: "", openDocuments: [], activeDocumentID: "")
    }

    private func scheduleAutosave(documentID: String) {
        autosaveTasks[documentID]?.cancel()
        let delay = autosaveDelay
        autosaveTasks[documentID] = Task { [weak self] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard let self else {
                return
            }
            self.autosaveTasks[documentID] = nil
            guard let document = self.workbench.openDocuments.first(where: { $0.id == documentID }), document.isDirty else {
                return
            }

            if self.workbench.saveDocument(document) {
                self.appendOutput("Autosaved \(document.relativePath)")
            }
        }
    }

    var projectURL: URL? {
        project.map { URL(fileURLWithPath: $0.path, isDirectory: true) }
    }

    var projectRootSidebarItem: EditorProjectSidebarViewModel.Item? {
        guard let project, let projectURL else {
            return nil
        }

        return EditorProjectSidebarViewModel.Item(
            id: projectURL.path,
            disclosure: "",
            icon: "",
            title: project.name,
            relativePath: "",
            level: 0,
            isActive: false,
            isFolder: true,
            kind: .folder
        )
    }

    var newFileNameBinding: Binding<String> {
        Binding(
            get: { self.newFileName },
            set: {
                self.newFileName = $0
                self.newFileErrorMessage = nil
            }
        )
    }

    var isNewFileDialogPresentedBinding: Binding<Bool> {
        Binding(
            get: { self.isNewFileDialogPresented },
            set: { isPresented in
                self.isNewFileDialogPresented = isPresented
                if !isPresented {
                    self.newFileErrorMessage = nil
                }
            }
        )
    }

    var newFileLocationTitle: String {
        newFileDestinationRelativePath.isEmpty ? (project?.name ?? "Project") : newFileDestinationRelativePath
    }

    var newFileExtensionHint: String {
        ".\(newFileKind.fileExtension)"
    }

    func presentNewFileDialog() {
        guard projectURL != nil else {
            appendOutput("New file is unavailable: no project is open.")
            return
        }

        let selectedItem = projectSidebar.selectedItem
        if let selectedItem {
            newFileDestinationRelativePath = selectedItem.isFolder
                ? selectedItem.relativePath
                : URL(fileURLWithPath: selectedItem.relativePath, isDirectory: false).deletingLastPathComponent().relativePath
            if newFileDestinationRelativePath == "." {
                newFileDestinationRelativePath = ""
            }
        } else {
            newFileDestinationRelativePath = ""
        }
        newFileName = ""
        newFileErrorMessage = nil
        isNewFileDialogPresented = true
    }

    func dismissNewFileDialog() {
        isNewFileDialogPresented = false
        newFileErrorMessage = nil
    }

    @discardableResult
    func createNewFile() -> Bool {
        guard let projectURL else {
            newFileErrorMessage = "No project is open."
            return false
        }

        let trimmedName = newFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            newFileErrorMessage = "Enter a file name."
            return false
        }
        guard trimmedName != ".", trimmedName != "..",
              !trimmedName.contains("/"), !trimmedName.contains("\\")
        else {
            newFileErrorMessage = "Enter a name without folders or path separators."
            return false
        }

        let enteredExtension = URL(fileURLWithPath: trimmedName, isDirectory: false).pathExtension
        guard enteredExtension.isEmpty || enteredExtension.caseInsensitiveCompare(newFileKind.fileExtension) == .orderedSame else {
            newFileErrorMessage = "\(newFileKind.title) files use the .\(newFileKind.fileExtension) extension."
            return false
        }

        let fileName = enteredExtension.isEmpty ? "\(trimmedName).\(newFileKind.fileExtension)" : trimmedName
        let destinationDirectory = newFileDestinationRelativePath.isEmpty
            ? projectURL
            : projectURL.appendingPathComponent(newFileDestinationRelativePath, isDirectory: true)
        let resolvedProjectURL = projectURL.resolvingSymlinksInPath().standardizedFileURL
        let resolvedDirectoryURL = destinationDirectory.resolvingSymlinksInPath().standardizedFileURL
        guard resolvedDirectoryURL.path == resolvedProjectURL.path
                || resolvedDirectoryURL.path.hasPrefix("\(resolvedProjectURL.path)/")
        else {
            newFileErrorMessage = "The selected folder is outside the project."
            return false
        }

        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: resolvedDirectoryURL.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            newFileErrorMessage = "The selected folder no longer exists."
            return false
        }

        let destinationURL = resolvedDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        guard !fileManager.fileExists(atPath: destinationURL.path) else {
            newFileErrorMessage = "A file named \(fileName) already exists."
            return false
        }

        do {
            try newFileKind.initialContent(fileName: fileName).write(to: destinationURL, atomically: true, encoding: .utf8)
            projectSidebar.items = Self.projectTreeItems(for: project, fileManager: fileManager)
            toolbar.searchableItems = projectSidebar.items
            refreshSourceControl()

            let relativePath = relativeProjectPath(for: destinationURL.path)
            if let item = projectSidebar.items.first(where: { $0.relativePath == relativePath }) {
                openProjectItem(item)
            }
            appendOutput("Created \(relativePath)")
            dismissNewFileDialog()
            return true
        } catch {
            newFileErrorMessage = "Unable to create the file: \(error.localizedDescription)"
            return false
        }
    }

    var dependencyLocationBinding: Binding<String> {
        Binding(get: { self.dependencyLocation }, set: { self.dependencyLocation = $0 })
    }

    var dependencyRequirementBinding: Binding<String> {
        Binding(get: { self.dependencyRequirement }, set: { self.dependencyRequirement = $0 })
    }

    var projectResourceRootsBinding: Binding<String> {
        Binding(get: { self.projectResourceRootsText }, set: { self.projectResourceRootsText = $0 })
    }

    var projectIncludedFilesBinding: Binding<String> {
        Binding(get: { self.projectIncludedFilesText }, set: { self.projectIncludedFilesText = $0 })
    }

    var projectExcludedFilesBinding: Binding<String> {
        Binding(get: { self.projectExcludedFilesText }, set: { self.projectExcludedFilesText = $0 })
    }

    func selectRunDestination(_ destination: EditorRunDestination) {
        selectedRunDestination = destination
        guard let projectURL else {
            return
        }
        do {
            try EditorProjectStore(fileManager: fileManager).setRunDestination(destination.adaProjectDestination, at: projectURL)
            projectSettingsStatusMessage = "Run destination saved."
        } catch {
            projectSettingsStatusMessage = "Failed to save run destination: \(error.localizedDescription)"
        }
    }

    func addProjectDependency() {
        guard let projectURL else {
            dependencyStatusMessage = "No project is open."
            return
        }
        let location = dependencyLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !location.isEmpty else {
            dependencyStatusMessage = "Enter a package URL or local path."
            return
        }

        do {
            let store = EditorProjectStore(fileManager: fileManager)
            let changed: Bool
            if location.hasPrefix("https://") || location.hasPrefix("http://") || location.hasPrefix("ssh://") || location.hasPrefix("git@") {
                changed = try store.addDependency(
                    to: projectURL,
                    url: location,
                    requirement: dependencyRequirement.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            } else {
                changed = try store.addLocalDependency(to: projectURL, path: location)
            }
            dependencyStatusMessage = changed ? "Dependency added. Resolving package graph…" : "Dependency is already present."
            dependencyLocation = ""
            if changed {
                bootstrapWorkspaceIfNeeded(force: true)
            }
        } catch {
            dependencyStatusMessage = "Failed to add dependency: \(error.localizedDescription)"
        }
    }

    func removeProjectDependency(identity: String) {
        guard let projectURL else {
            dependencyStatusMessage = "No project is open."
            return
        }
        do {
            let changed = try EditorProjectStore(fileManager: fileManager).removeDependency(from: projectURL, identity: identity)
            dependencyStatusMessage = changed ? "Removed \(identity). Resolving package graph…" : "Dependency \(identity) was not found."
            if changed {
                bootstrapWorkspaceIfNeeded(force: true)
            }
        } catch {
            dependencyStatusMessage = "Failed to remove \(identity): \(error.localizedDescription)"
        }
    }

    func saveProjectSettings() {
        guard let projectURL else {
            projectSettingsStatusMessage = "No project is open."
            return
        }
        guard let targetName = selectedRunTargetName else {
            projectSettingsStatusMessage = "Load the package and select an executable target first."
            return
        }

        do {
            var settings = try ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
            settings.paths.resourceRoots = Self.pathList(from: projectResourceRootsText)
            settings.build.includedFiles = Self.pathList(from: projectIncludedFilesText)
            settings.build.excludedFiles = Self.pathList(from: projectExcludedFilesText)
            settings.run.destination = selectedRunDestination.adaProjectDestination
            try EditorProjectStore(fileManager: fileManager).saveProjectSettings(settings, at: projectURL, targetName: targetName)
            projectSettingsStatusMessage = "Project settings saved to .ada/project.json and Package.swift."
            bootstrapWorkspaceIfNeeded(force: true)
        } catch {
            projectSettingsStatusMessage = "Failed to save project settings: \(error.localizedDescription)"
        }
    }

    private static func pathList(from text: String) -> [String] {
        var seen = Set<String>()
        return text
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private static func editorRunDestination(from destination: AdaProjectRunDestination) -> EditorRunDestination {
        switch destination {
        case .macOS: .macOS
        case .web: .web
        }
    }

    var runProducts: [String] {
        packageModel?.executableProducts.map(\.name).sorted() ?? []
    }

    var selectedRunTargetName: String? {
        guard let productName = selectedRunProduct ?? runProducts.first else {
            return nil
        }
        return packageModel?.executableTargetName(forProductNamed: productName)
    }

    var testTargets: [String] {
        packageModel?.testTargets.sorted() ?? []
    }

    func startEditorSessionIfNeeded() {
        guard !didStartEditorSession else {
            return
        }

        didStartEditorSession = true
        bootstrapWorkspaceIfNeeded()
        refreshSourceControl()
    }

    func bootstrapWorkspaceIfNeeded(force: Bool = false) {
        guard workspaceTask == nil, let projectURL else {
            return
        }
        guard force || workspaceStatus == .idle || packageModel == nil else {
            return
        }

        workspaceStatus = .resolving
        buildActivity = EditorBuildActivity(title: "Prepare Workspace")
        footer.setWorkspaceFooterTitle("Workspace: Preparing")
        lastLoggedWorkspaceProgressPhase = nil
        appendOutput("Loading \(ProjectSystem.metadataFileName) and resolving SwiftPM dependencies...")

        workspaceTask = Task { [weak self] in
            guard let self else { return }
            await self.workspaceService.setDiagnosticsHandler { [weak self] uri, diagnostics in
                await MainActor.run {
                    self?.receiveSourceDiagnostics(diagnostics, uri: uri)
                }
            }
            let result = await self.workspaceService.bootstrap(projectURL: projectURL) { progress in
                await MainActor.run {
                    self.handleWorkspaceProgress(progress)
                }
            }
            await MainActor.run {
                self.packageModel = result.packageModel
                self.problems = Self.replacingBuildDiagnostics(in: self.problems, with: result.diagnostics)
                self.showProblemsIfNeeded()
                let failureOutput = result.describeResult.combinedOutput.isEmpty
                    ? result.resolveResult.combinedOutput
                    : result.describeResult.combinedOutput
                self.workspaceStatus = result.succeeded ? .ready : .failed(failureOutput)
                self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                self.selectedRunProduct = self.selectedRunProduct ?? self.runProducts.first
                self.appendOutput(result.resolveResult)
                self.appendOutput(result.describeResult)
                if let indexBuildResult = result.indexBuildResult {
                    self.workspaceStatus = indexBuildResult.succeeded ? .ready : .failed(indexBuildResult.combinedOutput)
                    self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                    self.appendOutput(indexBuildResult)
                }
                self.buildActivity?.finish(
                    succeeded: result.succeeded && result.indexBuildResult?.succeeded != false
                )
                self.workspaceTask = nil
                self.refreshPreviewForActiveDocument()
            }
        }
    }

    func refreshSourceControl() {
        guard let projectURL else {
            sourceControl.snapshot = .empty
            sourceControl.statusMessage = "No project is open."
            footer.setSourceControlFooterTitle("Git: unavailable")
            return
        }

        sourceControlTask?.cancel()
        sourceControl.isRunning = true
        sourceControl.statusMessage = "Refreshing source control..."

        sourceControlTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.sourceControlService.snapshot(projectURL: projectURL)
            await MainActor.run {
                self.sourceControl.snapshot = result.snapshot
                self.sourceControl.statusMessage = self.sourceControlStatusMessage(for: result)
                self.sourceControl.isRunning = false
                self.footer.setSourceControlFooterTitle(result.snapshot.footerTitle)
                if !result.succeeded {
                    self.appendOutput(result.statusResult)
                    if let branchResult = result.branchResult, !branchResult.succeeded {
                        self.appendOutput(branchResult)
                    }
                }
                self.sourceControlTask = nil
            }
        }
    }

    func stageSourceControlFile(_ path: String) {
        executeSourceControlCommand(.stage(paths: [path]), statusTitle: "Stage \(path)")
    }

    func stageAllSourceControlFiles() {
        executeSourceControlCommand(.stage(paths: []), statusTitle: "Stage All")
    }

    func unstageSourceControlFile(_ path: String) {
        executeSourceControlCommand(.unstage(paths: [path]), statusTitle: "Unstage \(path)")
    }

    func unstageAllSourceControlFiles() {
        executeSourceControlCommand(.unstage(paths: []), statusTitle: "Unstage All")
    }

    func stashSourceControlChanges() {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        executeSourceControlCommand(.stash(message: "AdaEditor stash \(timestamp)"), statusTitle: "Stash")
    }

    func commitSourceControlChanges() {
        let message = sourceControl.trimmedCommitMessage
        guard !message.isEmpty else {
            sourceControl.statusMessage = "Enter a commit message."
            return
        }

        guard !sourceControl.snapshot.stagedFiles.isEmpty else {
            sourceControl.statusMessage = "Stage files before committing."
            return
        }

        executeSourceControlCommand(.commit(message: message), statusTitle: "Commit", clearsCommitMessage: true)
    }

    func pullSourceControlChanges() {
        executeSourceControlCommand(.pull, statusTitle: "Pull")
    }

    func pushSourceControlChanges() {
        executeSourceControlCommand(.push, statusTitle: "Push")
    }

    func checkoutSourceControlBranch(_ branch: GitBranch) {
        guard !branch.isCurrent else {
            return
        }

        executeSourceControlCommand(.checkout(branch: branch.name), statusTitle: "Checkout \(branch.name)")
    }

    func createSourceControlBranch() {
        let branchName = sourceControl.trimmedNewBranchName
        guard !branchName.isEmpty else {
            sourceControl.statusMessage = "Enter a branch name."
            return
        }

        executeSourceControlCommand(.createBranch(name: branchName), statusTitle: "Create Branch \(branchName)", clearsNewBranchName: true)
    }

    func buildAll() {
        executeWorkspaceCommand(.build(target: nil, buildTests: true), statusTitle: "Build")
    }

    func buildTarget(_ target: String) {
        executeWorkspaceCommand(.build(target: target, buildTests: false), statusTitle: "Build \(target)")
    }

    func runSelectedTarget() {
        let product = selectedRunProduct ?? runProducts.first
        if workbench.activeDocument?.isDirty == true {
            guard saveActiveDocumentIfNeeded() else {
                let detail = workbench.activeDocumentSaveFailureDescription ?? "the active document could not be saved"
                workspaceStatus = .failed("Run blocked: \(detail)")
                footer.setWorkspaceFooterTitle(workspaceStatus.title)
                appendOutput("Run blocked: \(detail)")
                return
            }
        }
        switch selectedRunDestination {
        case .macOS:
            executeWorkspaceCommand(.run(target: product, arguments: []), statusTitle: product.map { "Run \($0) on macOS" } ?? "Run on macOS")
        case .web:
            guard let product else {
                workspaceStatus = .failed("Select an executable product before running for Web.")
                return
            }
            executeWorkspaceCommand(
                .runWeb(target: product, outputPath: "dist/web", serve: true),
                statusTitle: "Run \(product) on Web · http://127.0.0.1:8080"
            )
        }
    }

    var isProjectRunning: Bool {
        if case .running = workspaceStatus {
            return true
        }
        return false
    }

    var activeActivities: [EditorActivityEvent] {
        EditorActivityPresentation.events(
            workspaceStatus: workspaceStatus,
            buildActivity: buildActivity,
            previewStatus: workbench.previewStatus,
            sourceControlIsRunning: sourceControl.isRunning,
            sourceControlTitle: sourceControl.statusMessage
        )
    }

    func runActiveSceneInEditor() {
        guard !playModeState.isPlaying else {
            return
        }

        guard let document = sceneDocumentForPlay() else {
            return
        }

        guard EditorSceneFileLoader.model(from: document.content) != nil else {
            failPlayMode("Unable to play \(document.title): scene document is invalid.")
            return
        }

        workbench.open(.scene(document))
        toolbar.sceneName = URL(fileURLWithPath: document.title).deletingPathExtension().lastPathComponent
        playModeState = .playing(sceneDocumentID: document.id, title: document.title)
        workspaceStatus = .running("Play \(document.title)")
        appendOutput("Playing \(document.relativePath)")
    }

    func stopPlayMode() {
        guard playModeState.isPlaying else {
            return
        }

        playModeState = .editing
        workspaceStatus = .ready
        appendOutput("Stopped Play Mode")
    }

    func runTests(filter: String? = nil) {
        executeWorkspaceCommand(.test(filter: filter ?? selectedTestFilter.nilIfEmpty), statusTitle: "Test")
    }

    func updateDependencies() {
        executeWorkspaceCommand(.update, statusTitle: "Update Dependencies")
    }

    func cleanPackageCache() {
        executeWorkspaceCommand(.clean, statusTitle: "Clean")
    }

    func resetPackageCache() {
        executeWorkspaceCommand(.reset, statusTitle: "Reset")
    }

    func cancelWorkspaceCommand() {
        workspaceTask?.cancel()
        workspaceTask = nil
        workspaceStatus = .cancelled
        Task {
            await workspaceService.cancel()
        }
    }

    @discardableResult
    func handleMenuCommand(_ command: EditorMenuCommand) -> Bool {
        switch command {
        case .showSettings:
            presentSettings(.general)
        case .newFile:
            presentNewFileDialog()
        case .newProject:
            ProjectEditorLauncher.openWelcome(beginCreatingProject: true)
        case .openProject:
            openProjectFromMenu()
        case .importAssets:
            importAssets()
        case .save:
            saveActiveDocument()
        case .saveAll:
            if workbench.saveAllDocuments() { refreshSourceControl() }
        case .findInProject:
            findInProjectRoot()
            _ = EditorSearchShortcutMonitor.shared.focusSearchField()
        case .navigateBack:
            navigateBack()
        case .navigateForward:
            navigateForward()
        case .showProjectNavigator:
            toolStrip.activeLeftTopTool = "fileTree"
            showLeftPanel = true
        case .showInspector:
            toolStrip.activeRightTool = "inspector"
            showRightPanel = true
        case .showBuildOutput:
            showBuildOutput()
        case .showProblems:
            showBottomPanel = true
            selectOutputTab("Problems")
        case .refreshProjectFiles:
            refreshProjectFiles()
        case .revealProject:
            if let projectURL { _ = EditorPlatformFileActions.reveal(projectURL) }
        case .openProjectInTerminal:
            if let projectURL { _ = EditorPlatformFileActions.openInTerminal(projectURL) }
        case .showProjectSettings:
            presentSettings(.project)
        case .showProjectDependencies:
            toolStrip.activeRightTool = "projectDependencies"
            showRightPanel = true
        case .showPackageTasks:
            toolStrip.activeRightTool = "swiftPackageTasks"
            showRightPanel = true
        case .build:
            buildAll()
        case .run:
            runSelectedTarget()
        case .runTests:
            runTests()
        case .stop:
            cancelWorkspaceCommand()
        case .clean:
            cleanPackageCache()
        case .updateDependencies:
            updateDependencies()
        case .rebuildPreview:
            rebuildSelectedPreview()
        case .closeEditorTab:
            workbench.closeDocument(id: workbench.activeDocumentID)
        case .closeAllEditorTabs:
            workbench.closeAllDocuments()
        case .increaseCodeFontSize:
            workbench.increaseCodeFontSize()
        case .decreaseCodeFontSize:
            workbench.decreaseCodeFontSize()
        case .resetCodeFontSize:
            workbench.resetCodeFontSize()
        case .closeEditor, .undo, .redo, .cut, .copy, .paste, .selectAll, .enterFullScreen,
             .minimizeWindow, .zoomWindow, .bringAllToFront, .showDocumentation, .showSourceRepository:
            return false
        }
        return true
    }

    func handleTextSelection(document: EditorTextDocument, range: EditorSourceRange?, text: String?) {
        workbench.updateTextDocument(id: document.id) { updatedDocument in
            updatedDocument.selectionRange = range
            updatedDocument.selectedText = text?.isEmpty == false ? text : nil
        }
    }

    func chatAboutTextSelection(document: EditorTextDocument, range: EditorSourceRange, text: String) {
        guard !text.isEmpty else {
            return
        }
        handleTextSelection(document: document, range: range, text: text)
        agent.prefillCodeSelection(EditorAgentCodeSelectionContext(
            documentTitle: document.title,
            documentRelativePath: document.relativePath,
            language: document.language.rawValue,
            range: range,
            text: text
        ))
        toolStrip.activeRightTool = "agentChat"
        showRightPanel = true
    }

    private func openProjectFromMenu() {
        guard workbench.saveAllDocuments(), let url = ProjectOpenPicker.pickProjectURL() else { return }
        do {
            let project = try EditorProjectStore(fileManager: fileManager).openProject(at: url)
            ProjectEditorLauncher.openEditor(for: project)
        } catch {
            workspaceStatus = .failed("Unable to open project: \(error.localizedDescription)")
            footer.setWorkspaceFooterTitle(workspaceStatus.title)
        }
    }

    private func refreshProjectFiles() {
        let selectedID = projectSidebar.selectedItem?.id
        let collapsedIDs = projectSidebar.collapsedFolderIDs
        let items = Self.projectTreeItems(for: project, fileManager: fileManager)
        projectSidebar.items = items
        projectSidebar.collapsedFolderIDs = collapsedIDs.intersection(Set(items.lazy.filter(\.isFolder).map(\.id)))
        if let selected = items.first(where: { $0.id == selectedID }) {
            projectSidebar.select(selected)
        }
        toolbar.searchableItems = items
        appendOutput("Refreshed project files")
    }

    func selectWorkbenchDocument(id documentID: String) {
        workbench.selectDocument(id: documentID)
        refreshPreviewForActiveDocument()
    }

    func navigateBack() {
        if workbench.navigateBack() {
            refreshPreviewForActiveDocument()
        }
    }

    func navigateForward() {
        if workbench.navigateForward() {
            refreshPreviewForActiveDocument()
        }
    }

    func saveActiveDocument() {
        if workbench.saveActiveDocument() {
            refreshSourceControl()
        }
    }

    @discardableResult
    func saveActiveDocumentIfNeeded() -> Bool {
        guard workbench.activeDocument?.isDirty == true else {
            return true
        }
        if workbench.saveActiveDocumentIfNeeded() {
            refreshSourceControl()
            return true
        }
        return false
    }

    func synchronizeAgentSceneContext() {
        guard case .scene(let document)? = workbench.activeDocument else {
            agent.setSceneContext(nil)
            return
        }

        agent.setSceneContext(EditorAgentSceneContext(document: document))
    }

    func selectPreview(_ declaration: EditorPreviewDeclaration) {
        workbench.selectedPreviewID = declaration.id
        buildPreview(declaration)
    }

    func rebuildSelectedPreview() {
        guard let document = activeSwiftTextDocument() else {
            workbench.previewStatus = .hidden
            return
        }

        let declarations = EditorPreviewScanner.declarations(in: document.content)
        guard !declarations.isEmpty else {
            workbench.previewStatus = .hidden
            return
        }

        let selected = declarations.first { $0.id == workbench.selectedPreviewID } ?? declarations[0]
        workbench.selectedPreviewID = selected.id
        buildPreview(selected)
    }

    func refreshPreviewForActiveDocument() {
        guard let document = activeSwiftTextDocument() else {
            workbench.previewStatus = .hidden
            workbench.selectedPreviewID = nil
            previewTask?.cancel()
            return
        }

        let declarations = EditorPreviewScanner.declarations(in: document.content)
        guard !declarations.isEmpty else {
            workbench.previewStatus = .hidden
            workbench.selectedPreviewID = nil
            previewTask?.cancel()
            return
        }

        let selected = declarations.first { $0.id == workbench.selectedPreviewID } ?? declarations[0]
        workbench.selectedPreviewID = selected.id

        guard packageModel != nil else {
            workbench.previewStatus = .unavailable("Resolve the SwiftPM workspace before building previews.")
            return
        }

        workbench.previewStatus = .available(declarations)
        buildPreview(selected)
    }

    private func sceneDocumentForPlay() -> EditorSceneDocument? {
        if let activeScene = workbench.activeSceneDocument {
            return activeScene
        }

        return startupSceneDocumentForPlay()
    }

    private func startupSceneDocumentForPlay() -> EditorSceneDocument? {
        guard let projectURL else {
            failPlayMode("No project is open and the active document is not a scene.")
            return nil
        }

        let projectMetadata: AdaProject
        do {
            projectMetadata = try ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
        } catch {
            failPlayMode("Unable to load \(ProjectSystem.metadataFileName): \(error.message)")
            return nil
        }

        guard let startupScene = projectMetadata.editor.startupScene, !startupScene.isEmpty else {
            failPlayMode("No active scene and \(ProjectSystem.metadataFileName) does not define editor.startupScene.")
            return nil
        }

        if case .scene(let openDocument)? = workbench.openDocuments.first(where: { document in
            guard case .scene(let sceneDocument) = document else {
                return false
            }
            return sceneDocument.relativePath == startupScene && (sceneDocument.absolutePath != nil || sceneDocument.isDirty)
        }) {
            return openDocument
        }

        let sceneURL = projectURL.appendingPathComponent(startupScene, isDirectory: false)
        guard fileManager.fileExists(atPath: sceneURL.path) else {
            failPlayMode("Startup scene not found: \(startupScene)")
            return nil
        }

        let content: String
        do {
            content = try String(contentsOf: sceneURL, encoding: .utf8)
        } catch {
            failPlayMode("Unable to read startup scene \(startupScene): \(error.localizedDescription)")
            return nil
        }

        let document = EditorSceneDocument(
            id: "scene:\(startupScene)",
            title: sceneURL.lastPathComponent,
            relativePath: startupScene,
            absolutePath: sceneURL.path,
            content: content,
            lastSavedContent: content,
            isReadOnly: Self.isSymbolicLink(at: sceneURL),
            sceneModel: EditorSceneFileLoader.model(from: content),
            errorMessage: nil,
            isDirty: false,
            statusMessage: Self.isSymbolicLink(at: sceneURL) ? "Read-only: symbolic link" : "Loaded",
            loadSummary: EditorSceneFileLoader.summary(from: content)
        )
        return document
    }

    private func failPlayMode(_ message: String) {
        playModeState = .failed(message)
        workspaceStatus = .failed(message)
        appendOutput("Play failed: \(message)")
    }

    func toggleDebugOverlay(_ type: UIDebugOverlayMode) {
        if showsDebugOverlay == type {
            showsDebugOverlay = nil
        } else {
            showsDebugOverlay = type
        }
    }

    func activateLeftTopTool(_ item: EditorToolStripItem) {
        if toolStrip.activeLeftTopTool == item.identifier && showLeftPanel {
            showLeftPanel = false
            return
        }

        toolStrip.selectLeftTopTool(item)
        showLeftPanel = true
    }

    func activateLeftBottomTool(_ item: EditorToolStripItem) {
        if toolStrip.activeLeftBottomTool == item.identifier && showBottomPanel {
            showBottomPanel = false
            return
        }

        toolStrip.selectLeftBottomTool(item)
        showBottomPanel = true
    }

    func activateRightTool(_ item: EditorToolStripItem) {
        switch item.identifier {
        case "projectSettings":
            presentSettings(.project)
            return
        default:
            break
        }

        if toolStrip.activeRightTool == item.identifier && showRightPanel {
            showRightPanel = false
            return
        }

        toolStrip.selectRightTool(item)
        showRightPanel = true
    }

    func presentSettings(_ section: EditorSettingsSection) {
        requestedSettingsSection = section
        settingsPresentationToken += 1
        showRightPanel = false
    }

    func isLeftTopToolPresented(_ item: EditorToolStripItem) -> Bool {
        toolStrip.activeLeftTopTool == item.identifier && showLeftPanel
    }

    func isLeftBottomToolPresented(_ item: EditorToolStripItem) -> Bool {
        toolStrip.activeLeftBottomTool == item.identifier && showBottomPanel
    }

    func isRightToolPresented(_ item: EditorToolStripItem) -> Bool {
        toolStrip.activeRightTool == item.identifier && showRightPanel
    }

    func selectOutputTab(_ tab: String) {
        activeOutputTab = tab
        workbench.activeOutputTab = tab
    }

    func clearOutput() {
        outputLines.removeAll()
        pendingWorkspaceStandardOutput = ""
        pendingWorkspaceStandardError = ""
    }

    func showBuildOutput() {
        showBottomPanel = true
        toolStrip.activeLeftBottomTool = "build"
        selectOutputTab("Build")
    }

    private func activeSwiftTextDocument() -> EditorTextDocument? {
        guard case .text(let document)? = workbench.activeDocument,
              document.language == .swift || document.language == .packageManifest
        else {
            return nil
        }

        return document
    }

    private func buildPreview(_ declaration: EditorPreviewDeclaration) {
        guard let projectURL, let packageModel, let document = activeSwiftTextDocument() else {
            workbench.previewStatus = .unavailable("Preview requires an open Swift package workspace.")
            return
        }

        previewTask?.cancel()
        workbench.previewStatus = .building(declaration, "Preparing preview build...")
        appendOutput("Building preview \(declaration.title) from \(document.relativePath)")

        let request = EditorPreviewBuildRequest(
            projectURL: projectURL,
            document: document,
            packageModel: packageModel,
            declaration: declaration
        )
        previewTask = Task { [weak self] in
            guard let self else { return }
            do {
                let artifact = try await self.previewBuilder.build(request)
                await MainActor.run {
                    guard case .text(let activeDocument)? = self.workbench.activeDocument,
                          activeDocument.id == document.id,
                          self.workbench.selectedPreviewID == declaration.id
                    else {
                        return
                    }

                    do {
                        self.appendOutputBlock(artifact.buildOutput)
                        let view = try self.previewLibrary.load(artifact: artifact)
                        self.workbench.previewStatus = .loaded(declaration, view)
                        self.appendOutput("Loaded preview \(declaration.title)")
                    } catch {
                        self.workbench.previewStatus = .failed(declaration, "Preview load failed. See Build Output for details.", true)
                        self.appendOutput("Preview load failed:")
                        self.appendOutputBlock(String(describing: error))
                    }
                    self.previewTask = nil
                }
            } catch {
                await MainActor.run {
                    self.workbench.previewStatus = .failed(declaration, "Preview build failed. See Build Output for details.", true)
                    self.appendOutput("Preview build failed:")
                    self.appendOutputBlock(String(describing: error))
                    self.previewTask = nil
                }
            }
        }
    }

    private func executeSourceControlCommand(
        _ kind: GitCommandKind,
        statusTitle: String,
        clearsCommitMessage: Bool = false,
        clearsNewBranchName: Bool = false
    ) {
        guard let projectURL else {
            sourceControl.statusMessage = "No project is open."
            footer.setSourceControlFooterTitle("Git: unavailable")
            return
        }

        sourceControlTask?.cancel()
        sourceControl.isRunning = true
        sourceControl.statusMessage = "Running \(statusTitle)..."
        appendOutput("$ \(statusTitle)")

        sourceControlTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.sourceControlService.execute(kind, projectURL: projectURL)
            await MainActor.run {
                self.appendOutput(result)
                self.sourceControl.statusMessage = result.succeeded
                    ? "\(statusTitle) finished."
                    : result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                self.sourceControl.isRunning = false
                self.sourceControlTask = nil
                if result.succeeded {
                    if clearsCommitMessage {
                        self.sourceControl.commitMessage = ""
                    }
                    if clearsNewBranchName {
                        self.sourceControl.newBranchName = ""
                    }
                }
                self.refreshSourceControl()
            }
        }
    }

    private func sourceControlStatusMessage(for result: GitRepositoryLoadResult) -> String {
        guard result.succeeded else {
            let statusOutput = result.statusResult.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            if !statusOutput.isEmpty {
                return statusOutput
            }

            let branchOutput = result.branchResult?.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return branchOutput.isEmpty ? "Source control unavailable." : branchOutput
        }

        if result.snapshot.hasChanges {
            return "\(result.snapshot.files.count) changed file\(result.snapshot.files.count == 1 ? "" : "s")."
        }

        return result.snapshot.statusMessage ?? "Working tree clean."
    }


    private func handleWorkspaceProgress(_ progress: SwiftPMWorkspaceProgress) {
        buildActivity?.consume(progress)
        switch progress.phase {
        case .ready:
            workspaceStatus = .ready
        case .failed:
            workspaceStatus = .failed(progress.detail ?? progress.title)
        case .resolvingDependencies:
            workspaceStatus = .resolving
        case .indexingBuild:
            workspaceStatus = .preparing(progress)
        default:
            workspaceStatus = .preparing(progress)
        }
        footer.setWorkspaceFooterTitle(workspaceStatus.title)

        if lastLoggedWorkspaceProgressPhase != progress.phase {
            appendOutput("Workspace: \(progress.progressText)")
            if let detail = progress.detail, !detail.isEmpty {
                appendOutput(detail)
            }
            if let command = progress.command {
                appendOutput("$ \(command.shellDescription)")
            }
            lastLoggedWorkspaceProgressPhase = progress.phase
        } else if progress.phase == .indexingBuild, let detail = progress.detail, !detail.isEmpty {
            appendOutput(detail)
        }
    }

    private func executeWorkspaceCommand(_ kind: SwiftPMCommandKind, statusTitle: String) {
        guard let projectURL else {
            workspaceStatus = .failed("No project is open.")
            return
        }

        workspaceTask?.cancel()
        workspaceStatus = .running(statusTitle)
        buildActivity = EditorBuildActivity(title: statusTitle)
        pendingWorkspaceStandardOutput = ""
        pendingWorkspaceStandardError = ""
        didReceiveStreamingWorkspaceOutput = false
        appendOutput("$ \(statusTitle)")
        workspaceTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.workspaceService.execute(kind, projectURL: projectURL) { [weak self] event in
                await MainActor.run {
                    self?.receiveWorkspaceOutput(event)
                }
            }
            guard !Task.isCancelled else {
                return
            }
            await MainActor.run {
                if self.didReceiveStreamingWorkspaceOutput {
                    self.flushPendingWorkspaceOutput()
                    self.appendOutput("Exited with code \(result.exitCode)")
                } else {
                    self.appendOutput(result)
                }
                self.buildActivity?.finish(succeeded: result.succeeded)
                self.problems = Self.replacingBuildDiagnostics(
                    in: self.problems,
                    with: EditorDiagnostic.diagnostics(from: result, projectURL: projectURL)
                )
                self.showProblemsIfNeeded()
                self.workspaceStatus = result.succeeded ? .ready : .failed(result.combinedOutput)
                self.workspaceTask = nil
            }
        }
    }

    private func receiveWorkspaceOutput(_ event: EditorProcessOutputEvent) {
        didReceiveStreamingWorkspaceOutput = true
        switch event.stream {
        case .standardOutput:
            let update = Self.streamingOutput(event.text, pending: pendingWorkspaceStandardOutput)
            pendingWorkspaceStandardOutput = update.pending
            appendStreamingLines(update.lines)
        case .standardError:
            let update = Self.streamingOutput(event.text, pending: pendingWorkspaceStandardError)
            pendingWorkspaceStandardError = update.pending
            appendStreamingLines(update.lines)
        }
    }

    private func appendStreamingLines(_ lines: [String]) {
        for line in lines {
            buildActivity?.consume(line)
        }
        appendOutput(lines)
    }

    private static func streamingOutput(_ text: String, pending: String) -> (lines: [String], pending: String) {
        let combined = pending + text
        let lines = combined.components(separatedBy: .newlines)
        let endsWithNewline = combined.last?.isNewline == true
        let completeLineCount = endsWithNewline ? lines.count : max(0, lines.count - 1)
        return (
            lines: lines.prefix(completeLineCount).filter { !$0.isEmpty },
            pending: endsWithNewline ? "" : lines.last ?? ""
        )
    }

    private func flushPendingWorkspaceOutput() {
        let pendingLines = [pendingWorkspaceStandardOutput, pendingWorkspaceStandardError].filter { !$0.isEmpty }
        for value in pendingLines {
            buildActivity?.consume(value)
        }
        appendOutput(pendingLines)
        pendingWorkspaceStandardOutput = ""
        pendingWorkspaceStandardError = ""
    }

    private func appendOutput(_ result: EditorProcessResult) {
        var lines = ["$ \(result.command.shellDescription)"]
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty {
            lines.append(contentsOf: output.components(separatedBy: .newlines))
        }
        lines.append("Exited with code \(result.exitCode)")
        appendOutput(lines)
    }

    private func appendOutput(_ text: String) {
        appendOutput([text])
    }

    private func appendOutput(_ lines: [String]) {
        outputLines = EditorWorkspaceLogBuffer.appending(lines, to: outputLines)
    }

    private func appendOutputBlock(_ text: String) {
        let output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            return
        }

        appendOutput(output.components(separatedBy: .newlines))
    }

    private func showProblemsIfNeeded() {
        guard !problems.isEmpty else {
            return
        }
        if !showBottomPanel {
            showBottomPanel = true
        }
        if activeOutputTab != "Problems" {
            selectOutputTab("Problems")
        }
    }

    func openProjectItem(_ item: EditorProjectSidebarViewModel.Item) {
        if item.isFolder {
            projectSidebar.toggleFolder(item)
            return
        }

        projectSidebar.select(item)
        let document = Self.document(for: item)
        workbench.open(document)
        refreshSemanticTokens(for: document)
        refreshPreviewForActiveDocument()

        if case .scene = document {
            toolbar.sceneName = URL(fileURLWithPath: item.title).deletingPathExtension().lastPathComponent
        }
    }

    func openSearchResult(_ item: EditorProjectSidebarViewModel.Item) {
        guard let currentItem = projectSidebar.items.first(where: { $0.id == item.id }) else {
            return
        }
        toolbar.clearSearch()
        openProjectItem(currentItem)
    }

    func findInProjectFolder(_ item: EditorProjectSidebarViewModel.Item) {
        if item.isFolder {
            toolbar.search(in: item)
            return
        }

        let parentPath = URL(fileURLWithPath: item.relativePath, isDirectory: false)
            .deletingLastPathComponent()
            .relativePath
        toolbar.search(in: projectSidebar.items.first { candidate in
            candidate.isFolder && candidate.relativePath == parentPath
        })
    }

    func findInProjectRoot() {
        toolbar.search(in: nil)
    }

    func revealProjectItem(_ item: EditorProjectSidebarViewModel.Item) {
        performPlatformFileAction(named: "Reveal in Finder", url: fileURL(for: item), action: EditorPlatformFileActions.reveal)
    }

    func openProjectItemInDefaultApplication(_ item: EditorProjectSidebarViewModel.Item) {
        performPlatformFileAction(named: "Open in Default App", url: fileURL(for: item), action: EditorPlatformFileActions.openInDefaultApplication)
    }

    func openProjectItemInTerminal(_ item: EditorProjectSidebarViewModel.Item) {
        performPlatformFileAction(named: "Open in Terminal", url: fileURL(for: item), action: EditorPlatformFileActions.openInTerminal)
    }

    func copyProjectItemPath(_ item: EditorProjectSidebarViewModel.Item, relative: Bool) {
        let value = relative ? item.relativePath : fileURL(for: item)?.path
        guard let value, EditorPlatformFileActions.copyToClipboard(value) else {
            appendOutput("Copy path is unavailable on this platform.")
            return
        }
        appendOutput("Copied \(relative ? "relative path" : "path"): \(value)")
    }

    func revealDocument(_ document: EditorWorkbenchDocument) {
        let url = document.absolutePath.map { URL(fileURLWithPath: $0, isDirectory: false) }
        performPlatformFileAction(named: "Reveal in Finder", url: url, action: EditorPlatformFileActions.reveal)
    }

    func copyDocumentPath(_ document: EditorWorkbenchDocument, relative: Bool) {
        let value = relative ? document.relativePath : document.absolutePath
        guard let value, EditorPlatformFileActions.copyToClipboard(value) else {
            appendOutput("Copy path is unavailable on this platform.")
            return
        }
        appendOutput("Copied \(relative ? "relative path" : "path"): \(value)")
    }

    private func fileURL(for item: EditorProjectSidebarViewModel.Item) -> URL? {
        Self.absoluteFilePath(from: item.id).map {
            URL(fileURLWithPath: $0, isDirectory: item.isFolder)
        }
    }

    private func performPlatformFileAction(
        named actionName: String,
        url: URL?,
        action: (URL) -> Bool
    ) {
        guard let url, action(url) else {
            appendOutput("\(actionName) is unavailable on this platform.")
            return
        }
        appendOutput("\(actionName): \(relativeProjectPath(for: url.path))")
    }

    @MainActor
    func importAssets() {
        guard let urls = ProjectOpenPicker.pickAssetImportURLs(), !urls.isEmpty else {
            return
        }

        importAssets(from: urls)
    }

    func importAssets(from sourceURLs: [URL]) {
        guard let projectURL else {
            appendOutput("Asset import failed: no project is open.")
            return
        }

        let assetsURL = Self.assetsDirectoryURL(for: projectURL, fileManager: fileManager)
        do {
            try fileManager.createDirectory(at: assetsURL, withIntermediateDirectories: true)
            for sourceURL in sourceURLs {
                let destinationURL = uniqueAssetDestinationURL(for: sourceURL, in: assetsURL)
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                appendOutput("Imported asset \(sourceURL.lastPathComponent) -> \(relativeProjectPath(for: destinationURL.path))")
            }
            try ensureAssetResourcesInManifest(projectURL: projectURL)
            projectSidebar.items = Self.projectTreeItems(for: project, fileManager: fileManager)
            toolbar.searchableItems = projectSidebar.items
            refreshSourceControl()
        } catch {
            appendOutput("Asset import failed: \(error.localizedDescription)")
            workspaceStatus = .failed(error.localizedDescription)
        }
    }

    private func uniqueAssetDestinationURL(for sourceURL: URL, in assetsURL: URL) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let pathExtension = sourceURL.pathExtension
        var candidate = assetsURL.appendingPathComponent(sourceURL.lastPathComponent, isDirectory: false)
        var counter = 2

        while fileManager.fileExists(atPath: candidate.path) {
            let name = pathExtension.isEmpty ? "\(baseName)-\(counter)" : "\(baseName)-\(counter).\(pathExtension)"
            candidate = assetsURL.appendingPathComponent(name, isDirectory: false)
            counter += 1
        }

        return candidate
    }

    private func ensureAssetResourcesInManifest(projectURL: URL) throws {
        let manifestURL = projectURL.appendingPathComponent("Package.swift", isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return
        }

        let manifest = try String(contentsOf: manifestURL, encoding: .utf8)
        let result = try PackageManifestEditor.edit(
            manifest,
            command: .ensureAssetResources(targetName: selectedRunTargetName, assetsPath: "Assets")
        )
        guard result.changed else {
            return
        }

        try result.manifest.write(to: manifestURL, atomically: true, encoding: .utf8)
        appendOutput("Updated Package.swift to copy Assets into the executable bundle.")
    }

    func openProjectItemAsRaw(_ item: EditorProjectSidebarViewModel.Item) {
        guard !item.isFolder else {
            return
        }

        projectSidebar.select(item)
        let content = Self.textFileContent(for: item)
        workbench.open(
            .text(
                EditorTextDocument(
                    id: "raw:\(item.relativePath)",
                    title: "\(item.title) Raw",
                    relativePath: item.relativePath,
                    absolutePath: Self.absoluteFilePath(from: item.id),
                    language: .yaml,
                    content: content.value,
                    lastSavedContent: content.errorMessage == nil ? content.value : nil,
                    isReadOnly: item.isSymbolicLink || content.errorMessage != nil,
                    errorMessage: content.errorMessage,
                    statusMessage: item.isSymbolicLink ? "Read-only: symbolic link" : content.errorMessage == nil ? nil : "Read-only: unable to read as UTF-8"
                )
            )
        )
        if let document = workbench.activeDocument {
            refreshSemanticTokens(for: document)
        }
    }

    func handleAgentProjectFileChanged(relativePath: String, fileManager: FileManager = .default) {
        projectSidebar.items = Self.projectTreeItems(for: project, fileManager: fileManager)
        toolbar.searchableItems = projectSidebar.items
        refreshSourceControl()
        guard let projectURL else {
            return
        }

        let changedURL = projectURL.appendingPathComponent(relativePath).standardizedFileURL
        for document in workbench.openDocuments {
            guard document.relativePath == relativePath else {
                continue
            }

            switch document {
            case .text(let textDocument):
                guard !textDocument.isDirty else {
                    continue
                }
                do {
                    let content = try String(contentsOf: changedURL, encoding: .utf8)
                    workbench.updateTextDocument(id: textDocument.id) { updatedDocument in
                        updatedDocument.content = content
                        updatedDocument.lastSavedContent = content
                        updatedDocument.isReadOnly = Self.isSymbolicLink(at: changedURL)
                        updatedDocument.errorMessage = nil
                        updatedDocument.statusMessage = updatedDocument.isReadOnly ? "Read-only: symbolic link" : "Reloaded"
                    }
                } catch {
                    workbench.updateTextDocument(id: textDocument.id) { updatedDocument in
                        updatedDocument.isReadOnly = true
                        updatedDocument.errorMessage = error.localizedDescription
                        updatedDocument.statusMessage = "Read-only: unable to read as UTF-8"
                    }
                }
            case .scene(var sceneDocument):
                guard !sceneDocument.isDirty else {
                    continue
                }
                do {
                    sceneDocument.content = try String(contentsOf: changedURL, encoding: .utf8)
                    sceneDocument.lastSavedContent = sceneDocument.content
                    sceneDocument.sceneModel = EditorSceneFileLoader.model(from: sceneDocument.content)
                    sceneDocument.loadSummary = EditorSceneFileLoader.summary(from: sceneDocument.content)
                    sceneDocument.statusMessage = "Reloaded"
                    sceneDocument.errorMessage = nil
                    workbench.replaceSceneDocument(sceneDocument)
                } catch {
                    sceneDocument.errorMessage = error.localizedDescription
                    sceneDocument.statusMessage = "Reload failed"
                    workbench.replaceSceneDocument(sceneDocument)
                }
            case .asset:
                continue
            }
        }
    }

    func handleSourceHover(document: EditorTextDocument, position: EditorSourceLocation?) {
        guard let position else {
            latestSourceHoverKey = nil
            workbench.updateTextDocument(id: document.id) { document in
                document.symbolHighlights = []
                document.sourceHoverRange = nil
                document.sourceHoverDescription = nil
            }
            return
        }

        guard supportsSourceNavigation(document) else {
            return
        }

        let hoverKey = "\(document.id):\(position.line):\(position.character)"
        latestSourceHoverKey = hoverKey
        workbench.updateTextDocument(id: document.id) { document in
            document.symbolHighlights = []
            document.sourceHoverRange = nil
            document.sourceHoverDescription = nil
        }

        Task { [weak self] in
            guard let self, let fileURL = document.fileURL else { return }
            async let highlightsRequest = self.workspaceService.documentHighlights(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )
            async let hoverRequest = self.workspaceService.hover(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )
            let (highlights, hover) = await (highlightsRequest, hoverRequest)
            let hoveredRange = hover?.range ?? highlights.first(where: { highlight in
                Self.sourceRange(highlight.range, contains: position)
            })?.range

            await MainActor.run {
                guard self.latestSourceHoverKey == hoverKey else {
                    return
                }

                self.workbench.updateTextDocument(id: document.id) { document in
                    document.symbolHighlights = highlights.map(\.range)
                    document.sourceHoverRange = hoveredRange
                    document.sourceHoverDescription = hover?.contents
                }
            }
        }
    }

    private static func sourceRange(_ range: EditorSourceRange, contains position: EditorSourceLocation) -> Bool {
        guard position.line >= range.start.line, position.line <= range.end.line else {
            return false
        }
        if position.line == range.start.line, position.character < range.start.character {
            return false
        }
        if position.line == range.end.line, position.character >= range.end.character {
            return false
        }
        return true
    }

    func handleCompletionPosition(document: EditorTextDocument, position: EditorSourceLocation, text: String) {
        completionTask?.cancel()
        completionTask = nil
        workbench.updateTextDocument(id: document.id) { updatedDocument in
            updatedDocument.completionItems = []
            updatedDocument.completionPosition = nil
        }
        guard supportsCompletions(document), let fileURL = document.fileURL else {
            return
        }
        guard Self.shouldRequestAutomaticCompletion(in: text, at: position) else {
            return
        }

        requestCompletions(document: document, fileURL: fileURL, position: position, text: text, delay: .milliseconds(140))
    }

    nonisolated static func shouldRequestAutomaticCompletion(in text: String, at position: EditorSourceLocation) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard position.line >= 0, position.line < lines.count, position.character > 0 else {
            return false
        }

        let line = lines[position.line]
        guard position.character <= line.count else {
            return false
        }

        let triggerIndex = line.index(line.startIndex, offsetBy: position.character - 1)
        let trigger = line[triggerIndex]
        return trigger == "." || trigger == "_" || trigger.isLetter || trigger.isNumber
    }

    func handleCompletionRequest(document: EditorTextDocument, position: EditorSourceLocation, text: String) {
        guard supportsCompletions(document), let fileURL = document.fileURL else {
            return
        }

        if case .text(let currentDocument)? = workbench.openDocuments.first(where: { $0.id == document.id }),
           !currentDocument.completionItems.isEmpty {
            completionTask?.cancel()
            completionTask = nil
            workbench.updateTextDocument(id: document.id) { updatedDocument in
                updatedDocument.completionItems = []
                updatedDocument.completionPosition = nil
            }
            return
        }

        completionTask?.cancel()
        completionTask = nil
        requestCompletions(document: document, fileURL: fileURL, position: position, text: text, delay: nil)
    }

    private func requestCompletions(
        document: EditorTextDocument,
        fileURL: URL,
        position: EditorSourceLocation,
        text: String,
        delay: Duration?
    ) {

        completionTask = Task { [weak self] in
            if let delay {
                do {
                    try await Task.sleep(for: delay)
                } catch {
                    return
                }
            }
            guard let self else { return }
            let items = await self.workspaceService.completions(
                fileURL: fileURL,
                language: document.language,
                text: text,
                position: position
            )
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self.workbench.updateTextDocument(id: document.id) { updatedDocument in
                    guard updatedDocument.content == text else {
                        return
                    }
                    updatedDocument.completionItems = Array(items.prefix(8))
                    updatedDocument.completionPosition = position
                }
                self.completionTask = nil
            }
        }
    }

    func applyCompletion(_ item: EditorCompletionItem, to document: EditorTextDocument) {
        guard let position = document.completionPosition,
              let edit = Self.applyingCompletion(item, to: document.content, at: position)
        else {
            return
        }

        workbench.updateTextDocument(id: document.id) { updatedDocument in
            updatedDocument.content = edit.text
            updatedDocument.isDirty = true
            updatedDocument.statusMessage = "Edited"
            updatedDocument.errorMessage = nil
            updatedDocument.completionItems = []
            updatedDocument.completionPosition = nil
            updatedDocument.focusedRange = EditorSourceRange(start: edit.caret, end: edit.caret)
        }
        completionTask?.cancel()
        completionTask = nil
    }

    static func applyingCompletion(
        _ item: EditorCompletionItem,
        to text: String,
        at position: EditorSourceLocation
    ) -> (text: String, caret: EditorSourceLocation)? {
        let lines = text.components(separatedBy: .newlines)
        guard lines.indices.contains(position.line) else {
            return nil
        }

        let range = item.replacementRange ?? inferredCompletionRange(in: lines[position.line], at: position)
        guard range.start.line == range.end.line,
              lines.indices.contains(range.start.line),
              range.start.character >= 0,
              range.end.character >= range.start.character,
              range.end.character <= lines[range.start.line].count
        else {
            return nil
        }

        var updatedLines = lines
        let line = updatedLines[range.start.line]
        let start = line.index(line.startIndex, offsetBy: range.start.character)
        let end = line.index(line.startIndex, offsetBy: range.end.character)
        updatedLines[range.start.line].replaceSubrange(start..<end, with: item.insertText)
        let insertedLines = item.insertText.components(separatedBy: .newlines)
        let caret = if insertedLines.count == 1 {
            EditorSourceLocation(line: range.start.line, character: range.start.character + item.insertText.count)
        } else {
            EditorSourceLocation(line: range.start.line + insertedLines.count - 1, character: insertedLines.last?.count ?? 0)
        }
        return (
            updatedLines.joined(separator: "\n"),
            caret
        )
    }

    private static func inferredCompletionRange(in line: String, at position: EditorSourceLocation) -> EditorSourceRange {
        let characters = Array(line)
        var start = min(max(0, position.character), characters.count)
        while start > 0 {
            let character = characters[start - 1]
            guard character == "_" || character.isLetter || character.isNumber else {
                break
            }
            start -= 1
        }
        return EditorSourceRange(
            start: EditorSourceLocation(line: position.line, character: start),
            end: position
        )
    }

    func receiveSourceDiagnostics(_ diagnostics: [EditorDiagnostic], uri: String) {
        let publishedPath = URL(string: uri)?.path.removingPercentEncoding ?? uri
        let affectedPaths = Set(diagnostics.map(\.filePath) + [publishedPath])

        let firstAffectedIndex = problems.firstIndex { diagnostic in
            diagnostic.source == "sourcekit-lsp" && affectedPaths.contains(diagnostic.filePath)
        }
        var updatedProblems = problems
        updatedProblems.removeAll { diagnostic in
            diagnostic.source == "sourcekit-lsp" && affectedPaths.contains(diagnostic.filePath)
        }
        let insertionIndex = min(firstAffectedIndex ?? updatedProblems.endIndex, updatedProblems.endIndex)
        updatedProblems.insert(contentsOf: diagnostics, at: insertionIndex)
        if updatedProblems != problems {
            problems = updatedProblems
        }
        for document in workbench.openDocuments {
            guard case .text(let textDocument) = document,
                  let absolutePath = textDocument.absolutePath,
                  affectedPaths.contains(absolutePath)
            else {
                continue
            }
            let documentDiagnostics = diagnostics.filter { $0.filePath == absolutePath }
            guard documentDiagnostics != textDocument.diagnostics else {
                continue
            }
            workbench.updateTextDocument(id: textDocument.id) { updatedDocument in
                updatedDocument.diagnostics = documentDiagnostics
            }
        }
        showProblemsIfNeeded()
    }

    static func replacingBuildDiagnostics(in existing: [EditorDiagnostic], with diagnostics: [EditorDiagnostic]) -> [EditorDiagnostic] {
        existing.filter { $0.source == "sourcekit-lsp" } + diagnostics.filter { $0.source != "sourcekit-lsp" }
    }

    func goToDefinition(document: EditorTextDocument, position: EditorSourceLocation) {
        guard supportsSourceNavigation(document), let fileURL = document.fileURL else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let targets = await self.workspaceService.definition(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )

            await MainActor.run {
                guard let target = targets.first else {
                    self.appendOutput("No definition found at \(document.relativePath):\(position.line + 1):\(position.character + 1)")
                    return
                }

                self.openSourceTarget(target)
            }
        }
    }

    func findReferences(document: EditorTextDocument, position: EditorSourceLocation) {
        guard supportsSourceNavigation(document), let fileURL = document.fileURL else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let references = await self.workspaceService.references(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )

            await MainActor.run {
                self.symbolReferences = references
                self.showBottomPanel = true
                self.selectOutputTab("References")
                self.appendOutput("Found \(references.count) references for \(document.relativePath):\(position.line + 1):\(position.character + 1)")
            }
        }
    }

    func showHoverInfo(document: EditorTextDocument, position: EditorSourceLocation) {
        guard supportsSourceNavigation(document), let fileURL = document.fileURL else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let hover = await self.workspaceService.hover(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )

            await MainActor.run {
                self.showBottomPanel = true
                self.selectOutputTab("Output")
                self.appendOutput(hover?.contents ?? "No hover information at \(document.relativePath):\(position.line + 1):\(position.character + 1)")
            }
        }
    }

    func sourceContextMenuItems(document: EditorTextDocument, position: EditorSourceLocation) -> [TextEditorContextMenuItem] {
        guard supportsSourceNavigation(document) else {
            return []
        }

        return [
            TextEditorContextMenuItem(
                title: "Go To",
                submenu: [
                    TextEditorContextMenuItem(title: "Definition") { [weak self] in
                        self?.goToDefinition(document: document, position: position)
                    },
                    TextEditorContextMenuItem(title: "References") { [weak self] in
                        self?.findReferences(document: document, position: position)
                    }
                ]
            ),
            TextEditorContextMenuItem(title: "Show Hover Info") { [weak self] in
                self?.showHoverInfo(document: document, position: position)
            },
            TextEditorContextMenuItem(title: "Document Highlights") { [weak self] in
                self?.handleSourceHover(document: document, position: position)
            },
            TextEditorContextMenuItem(title: "Rename (Unavailable)"),
            TextEditorContextMenuItem(title: "Code Actions (Unavailable)")
        ]
    }

    private func refreshSemanticTokens(for document: EditorWorkbenchDocument) {
        guard case .text(let textDocument) = document,
              (textDocument.language == .swift || textDocument.language == .packageManifest),
              let absolutePath = textDocument.absolutePath
        else {
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let tokens = await self.workspaceService.semanticTokens(
                fileURL: URL(fileURLWithPath: absolutePath, isDirectory: false),
                language: textDocument.language,
                text: textDocument.content
            )
            guard !tokens.isEmpty else {
                return
            }

            await MainActor.run {
                self.workbench.updateTextDocument(id: textDocument.id) { document in
                    document.semanticTokens = tokens
                }
            }
        }
    }

    private func supportsSourceNavigation(_ document: EditorTextDocument) -> Bool {
        (document.language == .swift || document.language == .packageManifest) && document.absolutePath != nil
    }

    private func supportsCompletions(_ document: EditorTextDocument) -> Bool {
        (document.language == .ada || document.language == .swift || document.language == .packageManifest) && document.absolutePath != nil
    }

    private func openSourceTarget(_ target: EditorSourceSymbolTarget) {
        let filePath = target.filePath
        if case .text(let document)? = workbench.openDocuments.first(where: { document in
            if case .text(let textDocument) = document {
                return textDocument.absolutePath == filePath
            }
            return false
        }) {
            workbench.updateTextDocument(id: document.id) { document in
                document.focusedRange = target.selectionRange
                document.symbolHighlights = [target.selectionRange]
            }
            workbench.selectDocument(id: document.id)
            return
        }

        let fileURL = URL(fileURLWithPath: filePath, isDirectory: false)
        let content: String
        let errorMessage: String?
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            errorMessage = nil
        } catch {
            content = ""
            errorMessage = error.localizedDescription
        }

        let relativePath = relativeProjectPath(for: filePath)
        let isSymbolicLink = Self.isSymbolicLink(at: fileURL)
        let textDocument = EditorTextDocument(
            id: "text:\(relativePath)",
            title: fileURL.lastPathComponent,
            relativePath: relativePath,
            absolutePath: filePath,
            language: EditorSourceLanguage.detect(fileName: fileURL.lastPathComponent),
            content: content,
            lastSavedContent: errorMessage == nil ? content : nil,
            isReadOnly: isSymbolicLink || errorMessage != nil,
            errorMessage: errorMessage,
            statusMessage: isSymbolicLink ? "Read-only: symbolic link" : errorMessage == nil ? nil : "Read-only: unable to read as UTF-8",
            symbolHighlights: [target.selectionRange],
            focusedRange: target.selectionRange
        )
        let workbenchDocument = EditorWorkbenchDocument.text(textDocument)
        workbench.open(workbenchDocument)
        refreshSemanticTokens(for: workbenchDocument)
    }

    private func relativeProjectPath(for filePath: String) -> String {
        guard let projectURL else {
            return filePath
        }

        let projectPath = projectURL.path
        guard filePath.hasPrefix(projectPath) else {
            return filePath
        }

        let start = filePath.index(filePath.startIndex, offsetBy: projectPath.count)
        return String(filePath[start...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func projectTreeItems(for project: EditorProjectReference?, fileManager: FileManager) -> [EditorProjectSidebarViewModel.Item] {
        guard let project else {
            return EditorProjectSidebarViewModel().items
        }

        let projectURL = URL(fileURLWithPath: project.path, isDirectory: true)
        return buildProjectTreeItems(at: projectURL, fileManager: fileManager)
    }

    private static func document(for item: EditorProjectSidebarViewModel.Item) -> EditorWorkbenchDocument {
        switch item.kind {
        case .scene:
            let content = sceneFileContent(for: item)
            let sceneModel = EditorSceneFileLoader.model(from: content.value)
            return .scene(
                EditorSceneDocument(
                    id: "scene:\(item.relativePath)",
                    title: item.title,
                    relativePath: item.relativePath,
                    absolutePath: absoluteFilePath(from: item.id),
                    content: content.value,
                    lastSavedContent: content.errorMessage == nil ? content.value : nil,
                    isReadOnly: item.isSymbolicLink,
                    sceneModel: sceneModel,
                    errorMessage: content.errorMessage,
                    isDirty: false,
                    statusMessage: item.isSymbolicLink ? "Read-only: symbolic link" : content.errorMessage == nil ? "Loaded" : nil,
                    loadSummary: EditorSceneFileLoader.summary(from: content.value)
                )
            )
        case .text(let language):
            let content = textFileContent(for: item)
            return .text(
                EditorTextDocument(
                    id: "text:\(item.relativePath)",
                    title: item.title,
                    relativePath: item.relativePath,
                    absolutePath: absoluteFilePath(from: item.id),
                    language: language,
                    content: content.value,
                    lastSavedContent: content.errorMessage == nil ? content.value : nil,
                    isReadOnly: item.isSymbolicLink || content.errorMessage != nil,
                    errorMessage: content.errorMessage,
                    statusMessage: item.isSymbolicLink ? "Read-only: symbolic link" : content.errorMessage == nil ? nil : "Read-only: unable to read as UTF-8"
                )
            )
        case .image, .audio, .genericAsset:
            return .asset(assetDocument(for: item))
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
        guard let absolutePath = absoluteFilePath(from: item.id) else {
            return (AdaEngineStyleContent.sampleTextDocuments[item.relativePath] ?? "", nil)
        }

        do {
            return (try String(contentsOf: URL(fileURLWithPath: absolutePath, isDirectory: false), encoding: .utf8), nil)
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
        let projectMetadata = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
        let assetsRoot = projectMetadata?.paths.assets ?? "Assets"
        let resourceRoots = Array(Set((projectMetadata?.paths.resourceRoots ?? []) + [assetsRoot]))
            .sorted { $0.count > $1.count }
        var items: [EditorProjectSidebarViewModel.Item] = []
        let rootEntries = (try? fileManager.contentsOfDirectory(
            at: projectURL,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )) ?? []

        for url in rootEntries.sorted(by: projectTreeSort) where !shouldSkipProjectTreeURL(url) {
            appendProjectTreeItems(
                url: url,
                projectURL: projectURL,
                level: 0,
                resourceRoots: resourceRoots,
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
        resourceRoots: [String],
        fileManager: FileManager,
        items: inout [EditorProjectSidebarViewModel.Item]
    ) {
        guard items.count < 2_000 else {
            return
        }

        let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        let isDirectory = resourceValues?.isDirectory == true
        let isSymbolicLink = resourceValues?.isSymbolicLink == true
        let relativePath = relativePath(for: url, projectURL: projectURL)
        let kind = fileKind(for: url, isDirectory: isDirectory)
        let itemAssetRoot = resourceRoots.first { root in
            let resourcePrefix = root.hasSuffix("/") ? root : "\(root)/"
            return relativePath == root || relativePath.hasPrefix(resourcePrefix)
        }

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
                isSymbolicLink: isSymbolicLink,
                kind: kind,
                assetRoot: itemAssetRoot
            )
        )

        guard isDirectory, !isSymbolicLink else {
            return
        }

        let childURLs = (try? fileManager.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey],
            options: []
        )) ?? []

        for childURL in childURLs.sorted(by: projectTreeSort) where !shouldSkipProjectTreeURL(childURL) {
            appendProjectTreeItems(
                url: childURL,
                projectURL: projectURL,
                level: level + 1,
                resourceRoots: resourceRoots,
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

        if isImageAsset(url) {
            return .image
        }

        if isAudioAsset(url) {
            return .audio
        }

        if isTextFile(url) {
            return .text(EditorSourceLanguage.detect(fileName: url.lastPathComponent))
        }

        return .genericAsset
    }

    private static func assetDocument(for item: EditorProjectSidebarViewModel.Item) -> EditorAssetDocument {
        let absolutePath = absoluteFilePath(from: item.id)
        let url = absolutePath.map { URL(fileURLWithPath: $0, isDirectory: false) }
        let values = url.flatMap { try? $0.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey]) }

        return EditorAssetDocument(
            id: "asset:\(item.relativePath)",
            title: item.title,
            relativePath: item.relativePath,
            absolutePath: absolutePath,
            assetReference: item.assetRoot.flatMap { assetReference(for: item.relativePath, assetsRoot: $0) },
            kind: assetPreviewKind(for: item.kind),
            fileExtension: URL(fileURLWithPath: item.title).pathExtension.lowercased(),
            byteCount: values?.fileSize.map(Int64.init),
            modifiedAt: values?.contentModificationDate,
            errorMessage: item.kind == .image && item.title.lowercased().hasSuffix(".png") == false ? "Only PNG image decoding is currently available in editor preview." : nil
        )
    }

    private static func assetPreviewKind(for kind: EditorProjectFileKind) -> EditorAssetPreviewKind {
        switch kind {
        case .image:
            return .image
        case .audio:
            return .audio
        default:
            return .generic
        }
    }

    static func assetReference(for relativePath: String, assetsRoot: String = "Assets") -> String? {
        let prefix = assetsRoot.hasSuffix("/") ? assetsRoot : "\(assetsRoot)/"
        guard relativePath == assetsRoot || relativePath.hasPrefix(prefix) else {
            return nil
        }

        let assetPath = relativePath == assetsRoot ? "" : String(relativePath.dropFirst(prefix.count))
        return "@res://\(assetPath)"
    }

    private static func assetsDirectoryURL(for projectURL: URL, fileManager: FileManager) -> URL {
        let projectMetadata = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
        return projectURL.appendingPathComponent(projectMetadata?.paths.assets ?? "Assets", isDirectory: true)
    }

    private static func isImageAsset(_ url: URL) -> Bool {
        ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "webp"].contains(url.pathExtension.lowercased())
    }

    private static func isAudioAsset(_ url: URL) -> Bool {
        ["wav", "mp3", "ogg", "flac", "m4a"].contains(url.pathExtension.lowercased())
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
        let skippedNames: Set<String> = [".ada", ".build", ".DS_Store", ".git", ".swiftpm", "DerivedData"]
        return skippedNames.contains(url.lastPathComponent)
    }

    private static func isSymbolicLink(at url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true
    }
}

private extension EditorRunDestination {
    var adaProjectDestination: AdaProjectRunDestination {
        switch self {
        case .macOS: .macOS
        case .web: .web
        }
    }
}
