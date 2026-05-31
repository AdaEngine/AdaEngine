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
    var errorMessage: String?
    var isDirty: Bool = false
    var statusMessage: String?
    var diagnostics: [EditorDiagnostic] = []
    var semanticTokens: [EditorSemanticToken] = []
    var symbolHighlights: [EditorSourceRange] = []
    var focusedRange: EditorSourceRange?
}

struct EditorSceneDocument: Equatable, Sendable {
    var id: String
    var title: String
    var relativePath: String
    var absolutePath: String?
    var content: String
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
        case .failed(let message):
            "Failed: \(message)"
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
    var id: String = UUID().uuidString
    var text: String
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
        var assetRoot: String? = nil
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
    var previewStatus: EditorPreviewStatus
    var selectedPreviewID: String?

    @ObservationIgnored
    private var onActiveDocumentChanged: (() -> Void)?
    @ObservationIgnored
    private var onActiveDocumentWillChange: (() -> Void)?

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
        guard let document = openDocuments.first(where: { $0.id == id }) else {
            return
        }

        if activeDocumentID != document.id {
            onActiveDocumentWillChange?()
            activeDocumentID = document.id
        }

        activeEditorTab = document.title
        onActiveDocumentChanged?()
    }

    func closeDocument(id documentID: String) {
        guard let closingIndex = openDocuments.firstIndex(where: { $0.id == documentID }) else {
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
        selectDocument(id: openDocuments[nextIndex].id)
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
    func saveActiveDocumentIfNeeded() -> Bool {
        guard let activeDocument, activeDocument.isDirty else {
            return false
        }

        return saveDocument(activeDocument)
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
            guard let absolutePath = document.absolutePath else {
                document.statusMessage = "Sample scene cannot be saved"
                return
            }

            do {
                try document.content.write(to: URL(fileURLWithPath: absolutePath), atomically: true, encoding: .utf8)
                document.isDirty = false
                document.errorMessage = nil
                document.statusMessage = "Saved"
                didSave = true
            } catch {
                document.statusMessage = "Save failed"
                document.errorMessage = error.localizedDescription
            }
        }
        return didSave
    }

    @discardableResult
    func saveTextDocument(id documentID: String) -> Bool {
        var didSave = false
        updateTextDocument(id: documentID) { document in
            guard let absolutePath = document.absolutePath else {
                document.statusMessage = "Sample file cannot be saved"
                return
            }

            do {
                try document.content.write(to: URL(fileURLWithPath: absolutePath, isDirectory: false), atomically: true, encoding: .utf8)
                document.isDirty = false
                document.errorMessage = nil
                document.statusMessage = "Saved"
                didSave = true
            } catch {
                document.statusMessage = "Save failed: \(error.localizedDescription)"
            }
        }
        return didSave
    }

    func replaceSceneDocument(_ document: EditorSceneDocument) {
        guard let index = openDocuments.firstIndex(where: { $0.id == document.id }) else {
            return
        }
        openDocuments[index] = .scene(document)
        notifyActiveDocumentChangedIfNeeded(documentID: document.id)
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

        update(&document)
        openDocuments[index] = .scene(document)
        notifyActiveDocumentChangedIfNeeded(documentID: documentID)
    }

    func updateTextDocument(id documentID: String, update: (inout EditorTextDocument) -> Void) {
        guard let index = openDocuments.firstIndex(where: { $0.id == documentID }) else {
            return
        }

        guard case .text(var document) = openDocuments[index] else {
            return
        }

        update(&document)
        openDocuments[index] = .text(document)
        notifyActiveDocumentChangedIfNeeded(documentID: documentID)
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
    var problems: [EditorDiagnostic]
    var symbolReferences: [EditorSourceReference]
    var selectedRunTarget: String?
    var selectedTestFilter: String
    var playModeState: EditorPlayModeState
    
    var showLeftPanel = true
    var showRightPanel = true
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
    private var didStartEditorSession = false
    @ObservationIgnored
    private var latestSourceHoverKey: String?
    @ObservationIgnored
    private var lastLoggedWorkspaceProgressPhase: SwiftPMWorkspaceBootstrapPhase?

    init(
        project: EditorProjectReference? = nil,
        fileManager: FileManager = .default,
        workspaceService: any SwiftPMWorkspaceServicing = SwiftPMWorkspaceService(),
        sourceControlService: any GitRepositoryServicing = GitRepositoryService(),
        previewBuilder: EditorPreviewBuilder = EditorPreviewBuilder(),
        toolbar: EditorToolbarViewModel = EditorToolbarViewModel(),
        toolStrip: EditorToolStripViewModel = EditorToolStripViewModel(),
        projectSidebar: EditorProjectSidebarViewModel? = nil,
        workbench: EditorWorkbenchViewModel = EditorWorkbenchViewModel(),
        inspectorSidebar: EditorInspectorSidebarViewModel = EditorInspectorSidebarViewModel(),
        agent: EditorAgentViewModel? = nil,
        sourceControl: EditorSourceControlViewModel = EditorSourceControlViewModel(),
        footer: EditorFooterViewModel = EditorFooterViewModel(),
        activeOutputTab: String = "Problems",
        workspaceStatus: EditorWorkspaceStatus = .idle,
        packageModel: SwiftPackageModel? = nil,
        outputLines: [EditorWorkspaceLogLine] = AdaEngineStyleContent.logLines.map { EditorWorkspaceLogLine(text: $0) },
        problems: [EditorDiagnostic] = [],
        symbolReferences: [EditorSourceReference] = [],
        selectedRunTarget: String? = nil,
        selectedTestFilter: String = "",
        playModeState: EditorPlayModeState = .editing
    ) {
        self.project = project
        self.workspaceService = workspaceService
        self.sourceControlService = sourceControlService
        self.fileManager = fileManager
        self.previewBuilder = previewBuilder
        self.toolbar = toolbar
        self.toolStrip = toolStrip
        self.projectSidebar = projectSidebar ?? EditorProjectSidebarViewModel(items: Self.projectTreeItems(for: project, fileManager: fileManager))
        self.workbench = workbench
        self.inspectorSidebar = inspectorSidebar
        self.agent = agent ?? EditorAgentViewModel(project: project, fileManager: fileManager)
        self.sourceControl = sourceControl
        self.activeOutputTab = activeOutputTab
        self.footer = footer
        self.workspaceStatus = workspaceStatus
        self.packageModel = packageModel
        self.outputLines = outputLines
        self.problems = problems
        self.symbolReferences = symbolReferences
        self.selectedRunTarget = selectedRunTarget
        self.selectedTestFilter = selectedTestFilter
        self.playModeState = playModeState
        self.agent.setProjectFileChangedHandler { [weak self] relativePath in
            self?.handleAgentProjectFileChanged(relativePath: relativePath, fileManager: fileManager)
        }
        self.workbench.setActiveDocumentWillChangeHandler { [weak self] in
            self?.saveActiveDocumentIfNeeded()
        }
        self.workbench.setActiveDocumentChangedHandler { [weak self] in
            self?.synchronizeAgentSceneContext()
        }
        synchronizeAgentSceneContext()
    }

    var projectURL: URL? {
        project.map { URL(fileURLWithPath: $0.path, isDirectory: true) }
    }

    var runTargets: [String] {
        packageModel?.executableTargets.sorted() ?? []
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
        footer.setWorkspaceFooterTitle("Workspace: Preparing")
        lastLoggedWorkspaceProgressPhase = nil
        appendOutput("Loading \(ProjectSystem.metadataFileName) and resolving SwiftPM dependencies...")

        workspaceTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.workspaceService.bootstrap(projectURL: projectURL) { progress in
                await MainActor.run {
                    self.handleWorkspaceProgress(progress)
                }
            }
            await MainActor.run {
                self.packageModel = result.packageModel
                self.problems = result.diagnostics
                self.showProblemsIfNeeded()
                let failureOutput = result.describeResult.combinedOutput.isEmpty
                    ? result.resolveResult.combinedOutput
                    : result.describeResult.combinedOutput
                self.workspaceStatus = result.succeeded ? .ready : .failed(failureOutput)
                self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                self.selectedRunTarget = self.selectedRunTarget ?? self.runTargets.first
                self.appendOutput(result.resolveResult)
                self.appendOutput(result.describeResult)
                if let indexBuildResult = result.indexBuildResult {
                    self.workspaceStatus = indexBuildResult.succeeded ? .ready : .failed(indexBuildResult.combinedOutput)
                    self.footer.setWorkspaceFooterTitle(self.workspaceStatus.title)
                    self.appendOutput(indexBuildResult)
                }
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
        let target = selectedRunTarget ?? runTargets.first
        executeWorkspaceCommand(.run(target: target, arguments: []), statusTitle: target.map { "Run \($0)" } ?? "Run")
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

    func selectWorkbenchDocument(id documentID: String) {
        workbench.selectDocument(id: documentID)
        refreshPreviewForActiveDocument()
    }

    func saveActiveDocument() {
        if workbench.saveActiveDocument() {
            refreshSourceControl()
        }
    }

    func saveActiveDocumentIfNeeded() {
        if workbench.saveActiveDocumentIfNeeded() {
            refreshSourceControl()
        }
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
            sceneModel: EditorSceneFileLoader.model(from: content),
            errorMessage: nil,
            isDirty: false,
            statusMessage: "Loaded",
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
        if toolStrip.activeRightTool == item.identifier && showRightPanel {
            showRightPanel = false
            return
        }

        toolStrip.selectRightTool(item)
        showRightPanel = true
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
        appendOutput("$ \(statusTitle)")
        workspaceTask = Task { [weak self] in
            guard let self else { return }
            let result = await self.workspaceService.execute(kind, projectURL: projectURL)
            await MainActor.run {
                self.appendOutput(result)
                self.problems = EditorDiagnostic.diagnostics(from: result, projectURL: projectURL)
                self.showProblemsIfNeeded()
                self.workspaceStatus = result.succeeded ? .ready : .failed(result.combinedOutput)
                self.workspaceTask = nil
            }
        }
    }

    private func appendOutput(_ result: EditorProcessResult) {
        appendOutput("$ \(result.command.shellDescription)")
        let output = result.combinedOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !output.isEmpty {
            for line in output.components(separatedBy: .newlines) {
                appendOutput(line)
            }
        }
        appendOutput("Exited with code \(result.exitCode)")
    }

    private func appendOutput(_ text: String) {
        outputLines.append(EditorWorkspaceLogLine(text: text))
        if outputLines.count > 400 {
            outputLines.removeFirst(outputLines.count - 400)
        }
    }

    private func appendOutputBlock(_ text: String) {
        let output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !output.isEmpty else {
            return
        }

        for line in output.components(separatedBy: .newlines) {
            appendOutput(line)
        }
    }

    private func showProblemsIfNeeded() {
        guard !problems.isEmpty else {
            return
        }

        showBottomPanel = true
        selectOutputTab("Problems")
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
            command: .ensureAssetResources(targetName: selectedRunTarget, assetsPath: "Assets")
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
                    errorMessage: content.errorMessage
                )
            )
        )
        if let document = workbench.activeDocument {
            refreshSemanticTokens(for: document)
        }
    }

    func handleAgentProjectFileChanged(relativePath: String, fileManager: FileManager = .default) {
        projectSidebar.items = Self.projectTreeItems(for: project, fileManager: fileManager)
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
                do {
                    let content = try String(contentsOf: changedURL, encoding: .utf8)
                    workbench.updateTextDocument(id: textDocument.id) { updatedDocument in
                        updatedDocument.content = content
                        updatedDocument.errorMessage = nil
                    }
                } catch {
                    workbench.updateTextDocument(id: textDocument.id) { updatedDocument in
                        updatedDocument.errorMessage = error.localizedDescription
                    }
                }
            case .scene(var sceneDocument):
                guard !sceneDocument.isDirty else {
                    continue
                }
                do {
                    sceneDocument.content = try String(contentsOf: changedURL, encoding: .utf8)
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
            }
            return
        }

        guard supportsSourceNavigation(document) else {
            return
        }

        let hoverKey = "\(document.id):\(position.line):\(position.character)"
        latestSourceHoverKey = hoverKey

        Task { [weak self] in
            guard let self, let fileURL = document.fileURL else { return }
            let highlights = await self.workspaceService.documentHighlights(
                fileURL: fileURL,
                language: document.language,
                text: document.content,
                position: position
            )

            await MainActor.run {
                guard self.latestSourceHoverKey == hoverKey else {
                    return
                }

                self.workbench.updateTextDocument(id: document.id) { document in
                    document.symbolHighlights = highlights.map(\.range)
                }
            }
        }
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
        let textDocument = EditorTextDocument(
            id: "text:\(relativePath)",
            title: fileURL.lastPathComponent,
            relativePath: relativePath,
            absolutePath: filePath,
            language: EditorSourceLanguage.detect(fileName: fileURL.lastPathComponent),
            content: content,
            errorMessage: errorMessage,
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
        let items = buildProjectTreeItems(at: projectURL, fileManager: fileManager)
        return items.isEmpty ? EditorProjectSidebarViewModel().items : items
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
                    sceneModel: sceneModel,
                    errorMessage: content.errorMessage,
                    isDirty: false,
                    statusMessage: content.errorMessage == nil ? "Loaded" : nil,
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
                    errorMessage: content.errorMessage
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
        let projectMetadata = try? ProjectSystem.loadProject(at: projectURL, fileManager: fileManager)
        let sourcesRoot = projectMetadata?.paths.sources ?? "Sources"
        let assetsRoot = projectMetadata?.paths.assets ?? "Assets"
        let rootEntries = [
            (path: sourcesRoot, assetRoot: Optional<String>.none),
            (path: assetsRoot, assetRoot: Optional(assetsRoot))
        ]
        var items: [EditorProjectSidebarViewModel.Item] = []

        for entry in rootEntries where !entry.path.isEmpty {
            let url = projectURL.appendingPathComponent(entry.path)
            guard fileManager.fileExists(atPath: url.path), !shouldSkipProjectTreeURL(url) else {
                continue
            }

            appendProjectTreeItems(
                url: url,
                projectURL: projectURL,
                level: 0,
                assetRoot: entry.assetRoot,
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
        assetRoot: String?,
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
                kind: kind,
                assetRoot: assetRoot
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
                assetRoot: assetRoot,
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
        let skippedNames: Set<String> = [".ada", ".build", ".git", ".swiftpm", "DerivedData", "Package.resolved", "Package.swift"]
        return skippedNames.contains(url.lastPathComponent)
    }
}
