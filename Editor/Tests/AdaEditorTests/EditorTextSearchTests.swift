@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
import AdaInput
import Foundation
import Math
import Testing

@Suite("Editor text search")
struct EditorTextSearchTests {
    private func fixture() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("text-search-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    @Test func unicodeLinesCaseAndWholeWords() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try "😀 Target target\r\n\r\nretarget Target\n".write(to: root.appendingPathComponent("code.swift"), atomically: true, encoding: .utf8)
        let service = EditorTextSearchService()
        let all = try await service.search(root: root, query: "target")
        #expect(all.matches.count == 4)
        #expect(all.matches.first?.range.start == EditorSourceLocation(line: 0, character: 3))
        #expect(all.matches.last?.range.start == EditorSourceLocation(line: 2, character: 9))
        let words = try await service.search(root: root, query: "target", wholeWord: true)
        #expect(words.matches.count == 3)
        let exact = try await service.search(root: root, query: "target", caseSensitive: true, wholeWord: true)
        #expect(exact.matches.count == 1)
    }

    @Test func buffersLiteralSearchExclusionsAndLimit() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("a.txt")
        try "disk".write(to: file, atomically: true, encoding: .utf8)
        for folder in [".build", ".git", "node_modules"] {
            let directory = root.appendingPathComponent(folder)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try "a.b".write(to: directory.appendingPathComponent("ignored.txt"), atomically: true, encoding: .utf8)
        }
        try Data([0, 97, 46, 98]).write(to: root.appendingPathComponent("binary"))
        try FileManager.default.createSymbolicLink(at: root.appendingPathComponent("link.txt"), withDestinationURL: file)
        let service = EditorTextSearchService()
        let result = try await service.search(root: root, query: "a.b", openBuffers: [file.path: "a.b axb a.b"])
        #expect(result.matches.count == 2)
        #expect(result.matches.allSatisfy { $0.relativePath == "a.txt" })
        #expect(result.skippedFiles == 1)
        let capped = try await service.search(root: root, query: "a.b", openBuffers: [file.path: "a.b a.b"], limit: 1)
        #expect(capped.matches.count == 1)
        #expect(capped.isTruncated)
        let exact = try await service.search(root: root, query: "a.b", openBuffers: [file.path: "a.b"], limit: 1)
        #expect(!exact.isTruncated)
    }

    @Test @MainActor func commandSearchAndNavigatePreserveBuffer() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        let file = root.appendingPathComponent("code.swift")
        try "let disk = 0".write(to: file, atomically: true, encoding: .utf8)
        let editor = EditorViewModel(project: EditorProjectReference(name: "Search", path: root.path))
        let item = try #require(editor.projectSidebar.items.first { $0.relativePath == "code.swift" })
        editor.openProjectItem(item)
        guard case .text(let document)? = editor.workbench.activeDocument else {
            Issue.record("Expected text document"); return
        }
        editor.workbench.updateTextDocument(id: document.id) { $0.content = "let unsaved = 1"; $0.isDirty = true }
        editor.textSearch.query = "unsaved"
        #expect(editor.handleMenuCommand(.findInProject))
        #expect(editor.textSearch.isPresented)
        for _ in 0..<100 where editor.textSearch.isSearching { try await Task.sleep(for: .milliseconds(20)) }
        let match = try #require(editor.textSearch.results.matches.first)
        editor.openTextSearchMatch(match)
        #expect(!editor.textSearch.isPresented)
        guard case .text(let opened)? = editor.workbench.activeDocument else {
            Issue.record("Expected search target"); return
        }
        #expect(opened.content == "let unsaved = 1")
        #expect(opened.isDirty)
        #expect(opened.focusedRange == match.range)
    }

    @Test @MainActor func latestQueryWinsAndCloseCancels() async throws {
        let root = try fixture()
        defer { try? FileManager.default.removeItem(at: root) }
        try "old new".write(to: root.appendingPathComponent("file"), atomically: true, encoding: .utf8)
        let model = EditorTextSearchModel()
        model.query = "old"
        model.search(root: root, openBuffers: [:])
        model.query = "new"
        model.search(root: root, openBuffers: [:])
        for _ in 0..<100 where model.isSearching { try await Task.sleep(for: .milliseconds(20)) }
        #expect(model.results.matches.first?.range.start.character == 4)
        model.query = "old"
        model.search(root: root, openBuffers: [:])
        model.close()
        try await Task.sleep(for: .milliseconds(250))
        #expect(model.results.matches.isEmpty)
        #expect(!model.isSearching)
    }

    @Test @MainActor func searchInputFocusUsesRealNodes() throws {
        var query = ""
        let container = UIContainerView(rootView: TextField("Search", text: Binding(
            get: { query }, set: { query = $0 }
        )).accessibilityIdentifier(EditorTextSearchDialog.fieldIdentifier))
        container.frame = Rect(x: 0, y: 0, width: 400, height: 80)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        #expect(EditorSearchShortcutMonitor.shared.focusSearchField(in: [container], identifier: EditorTextSearchDialog.fieldIdentifier))
        let diagnostics = try container.uiLayoutDiagnostics(matching: nil, subtreeDepth: nil)
        #expect(diagnostics.textInputFocused)
    }
}

@MainActor @Suite(.serialized)
struct EditorTextSearchDialogTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "TextSearchTests")))
        }
    }

    @Test func shortcutInputResultsOpenAndEscape() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("search-ui-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try "first needle\nsecond needle".write(to: root.appendingPathComponent("example.swift"), atomically: true, encoding: .utf8)
        let editor = EditorViewModel(project: EditorProjectReference(name: "Search", path: root.path))
        let container = UIContainerView(rootView: Color.clear
            .modifier(EditorTextSearchPresentation(viewModel: editor)).theme(.adaEditor))
        container.frame = Rect(x: 0, y: 0, width: 1200, height: 800)
        container.bounds.size = container.frame.size
        container.layoutSubviews()
        container.onKeyEvent(KeyEvent(window: RID(), keyCode: .f, modifiers: [.main, .shift], status: .down, time: 0, isRepeated: false))
        await refresh(container)
        #expect(editor.textSearch.isPresented)
        let dialog = try container.uiNode(matching: .accessibilityIdentifier("AdaEditor.TextSearch.Dialog"))
        #expect(dialog.absoluteFrame.width <= 1200)
        #expect(dialog.absoluteFrame.height <= 800)
        #expect(EditorSearchShortcutMonitor.shared.focusSearchField(in: [container], identifier: EditorTextSearchDialog.fieldIdentifier))
        container.onTextInputEvent(TextInputEvent(window: RID(), text: "needle", action: .insert, time: 0))
        for _ in 0..<100 where editor.textSearch.isSearching { try await Task.sleep(for: .milliseconds(20)) }
        await refresh(container)
        #expect(editor.textSearch.query == "needle")
        #expect(editor.textSearch.results.matches.count == 2)
        container.onKeyEvent(KeyEvent(window: RID(), keyCode: .arrowDown, modifiers: [], status: .down, time: 1, isRepeated: false))
        await refresh(container)
        #expect(editor.textSearch.selectedMatch?.range.start.line == 1)
        container.onKeyEvent(KeyEvent(window: RID(), keyCode: .enter, modifiers: [], status: .down, time: 2, isRepeated: false))
        await refresh(container)
        #expect(!editor.textSearch.isPresented)
        guard case .text(let document)? = editor.workbench.activeDocument else {
            Issue.record("Search must open the selected file"); return
        }
        #expect(document.focusedRange?.start.line == 1)
        container.onKeyEvent(KeyEvent(window: RID(), keyCode: .f, modifiers: [.main, .shift], status: .down, time: 3, isRepeated: false))
        await refresh(container)
        #expect(editor.textSearch.isPresented)
        container.onKeyEvent(KeyEvent(window: RID(), keyCode: .escape, modifiers: [], status: .down, time: 4, isRepeated: false))
        await refresh(container)
        #expect(!editor.textSearch.isPresented)
        #expect(container.uiFindNodes(matching: .accessibilityIdentifier("AdaEditor.TextSearch.Dialog")).isEmpty)
    }

    private func refresh(_ container: UIView) async {
        for _ in 0..<10 {
            await Task.yield()
            container.update(1.0 / 60.0)
            container.layoutIfNeeded()
        }
    }
}
