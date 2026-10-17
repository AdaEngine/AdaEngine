import AdaInput
import AdaUtils
import Math
import Testing
@testable import AdaPlatform
@testable import AdaUI

@MainActor
@Suite(.serialized)
struct TextInputCompositionTests {
    init() async throws { try Application.prepareForTest() }

    @Test("IME updates replace marked text and commit exactly once", arguments: [false, true])
    func liveComposition(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.setComposingText, "h")
        #expect(field.value == "h")
        field.send(.setComposingText, "he")
        #expect(field.value == "he")
        field.send(.commitText, "hello")
        field.send(.finishComposingText)
        #expect(field.value == "hello")
        field.send(.commitText, "!")
        #expect(field.value == "hello!")
    }

    @Test("Composition captures selected range and supports shortening and empty replacement", arguments: [false, true])
    func selectedReplacement(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "AoldZ")
        field.select(1, 4)
        field.send(.setComposingText, "long")
        #expect(field.value == "AlongZ")
        field.send(.setComposingText, "x")
        #expect(field.value == "AxZ")
        field.send(.setComposingText, "")
        #expect(field.value == "AZ")
        field.send(.commitText, "ok")
        #expect(field.value == "AokZ")
    }

    @Test("Finishing composition keeps visible text without inserting twice", arguments: [false, true])
    func finish(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.setComposingText, "word")
        field.send(.finishComposingText)
        field.send(.finishComposingText)
        #expect(field.value == "word")
        field.send(.setComposingText, " next")
        #expect(field.value == "word next")
    }

    @Test("Marked combining scalars do not take ownership of adjacent existing text", arguments: [false, true])
    func combiningBoundary(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "eZ")
        field.select(1, 1)
        field.send(.setComposingText, "\u{301}")
        #expect(Array(field.value.unicodeScalars).map(\.value) == [101, 769, 90])
        field.send(.setComposingText, "")
        #expect(field.value == "eZ")
        field.send(.setComposingText, "👨‍👩‍👧‍👦")
        field.send(.commitText, "😀")
        #expect(field.value == "e😀Z")
        #expect(field.head == 2)
    }

    @Test("Surrounding deletion respects UTF16, code points and both directions", arguments: [false, true])
    func surroundingDeletion(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "A😀BC")
        field.select(2, 2)
        field.send(.deleteSurroundingTextInCodePoints, start: 1, end: 1)
        #expect(field.value == "AC")
        field.send(.commitText, "😀")
        field.send(.deleteSurroundingText, start: 2)
        #expect(field.value == "AC")
        field.send(.commitText, "😀")
        field.send(.deleteSurroundingText, start: 1)
        #expect(field.value == "AC") // no dangling UTF16 surrogate
    }

    @Test("Surrounding deletion excludes marked text as Android's Editable does", arguments: [false, true])
    func deletionAroundComposition(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "ABZ")
        field.select(2, 2)
        field.send(.setComposingText, "hello")
        field.send(.deleteSurroundingText, start: 1, end: 1)
        #expect(field.value == "Ahello")
        field.send(.setComposingText, "hi")
        #expect(field.value == "Ahi")
    }

    @Test("Same-field caret movement ends composition and rejects queued session input", arguments: [false, true])
    func caretMove(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "AZ")
        field.select(1, 1)
        let session = TextInputEvent.Session()
        field.send(.setComposingText, "old", session: session)
        field.select(0, 0)
        #expect(!session.isActive)
        field.send(.commitText, "stale", session: session)
        #expect(field.value == "AoldZ")
        field.send(.setComposingText, "new")
        #expect(field.value == "newAoldZ")
    }

    @Test("Focus loss and reopening discard composition ownership", arguments: [false, true])
    func focusLifecycle(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "A")
        field.select(1, 1)
        let session = TextInputEvent.Session()
        field.send(.setComposingText, "first", session: session)
        field.unfocus()
        field.focus()
        field.send(.commitText, "stale", session: session)
        field.send(.setComposingText, "second")
        #expect(field.value == "Afirstsecond")
    }

    @Test("Ordinary edits and external binding changes discard native composition", arguments: [false, true])
    func externalChanges(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.setComposingText, "old")
        field.send(.insert, "!")
        field.send(.setComposingText, "new")
        #expect(field.value == "old!new")
        field.replaceExternally("external")
        field.select(0, 0)
        field.send(.setComposingText, "fresh")
        #expect(field.value == "freshexternal")
    }

    @Test("IME range and cursor operations use UTF16 offsets", arguments: [false, true])
    func composingRegion(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.commitText, "A😀Z")
        field.send(.setComposingRegion, start: -3, end: -1)
        field.send(.setComposingText, "x", cursor: 0)
        #expect(field.value == "AxZ")
        #expect(field.head == 1)
        field.send(.commitText, "yes")
        #expect(field.value == "AyesZ")
        field.send(.setSelection, start: -3, end: -3)
        field.send(.commitText, "!")
        #expect(field.value == "A!yesZ")
    }

    @Test("Reversed IME selection keeps the active head as the relative range origin", arguments: [false, true])
    func reversedSelection(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.commitText, "abcdef")
        field.send(.setSelection, start: -2, end: -4)
        #expect(field.head == 2)
        field.send(.setComposingRegion, start: -2, end: 0)
        field.send(.commitText, "X")
        #expect(field.value == "Xcdef")
    }

    @Test("Finishing and marking text preserve an existing IME selection", arguments: [false, true])
    func finishPreservesSelection(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.commitText, "abcdef")
        field.send(.setSelection, start: -4, end: -2)
        field.send(.setComposingRegion, start: -4, end: -2)
        field.send(.finishComposingText)
        #expect(field.head == 4)
        field.send(.commitText, "X")
        #expect(field.value == "abXef")
    }

    @Test("First native event preserves direction of the control's selection", arguments: [false, true])
    func initialSelectionDirection(editor: Bool) throws {
        let field = try Harness(editor: editor, text: "abcdef")
        field.select(4, 2)
        field.send(.finishComposingText)
        #expect(field.head == 2)
        field.send(.setComposingRegion, start: -2, end: 0)
        field.send(.commitText, "X")
        #expect(field.value == "Xcdef")
    }

    @Test("Empty marked text and empty regions release composition ownership", arguments: [false, true])
    func emptyComposition(editor: Bool) throws {
        let field = try Harness(editor: editor)
        field.send(.commitText, "abcdef")
        field.send(.setSelection, start: -4, end: -4)
        field.send(.setComposingText, "")
        field.send(.setSelection, start: 2, end: 2)
        field.send(.commitText, "X")
        #expect(field.value == "abcdXef")
        field.send(.setComposingRegion, start: -3, end: -3)
        field.send(.commitText, "Y")
        #expect(field.value == "abcdXYef")
    }

    @Test("IME replacement bypasses closing-brace autoindent")
    func braceCommit() throws {
        let field = try Harness(editor: true, text: "{\n    ")
        field.select(field.value.count, field.value.count)
        field.send(.setComposingText, "}")
        field.send(.commitText, "}")
        #expect(field.value == "{\n    }")
    }
}

@MainActor
private final class Harness {
    var value: String
    private let container: UIContainerView<AnyView>
    private let node: ViewNode

    init(editor: Bool, text: String = "") throws {
        // Detached model permits closures before this harness is initialized.
        let model = TextValue(text)
        let binding = Binding(get: { model.text }, set: { model.text = $0 })
        let content: AnyView = editor
            ? AnyView(TextEditor(text: binding, foldingStyle: .braces).frame(width: 240, height: 100))
            : AnyView(TextField("", text: binding).frame(width: 240, height: 36))
        let view = UIContainerView(rootView: content)
        view.frame = Rect(x: 0, y: 0, width: 260, height: 120)
        view.layoutSubviews()
        func find(_ node: ViewNode) -> ViewNode? {
            if node is TextFieldViewNode || node is TextEditorViewNode { return node }
            return node.transientEnvironmentChildren.lazy.compactMap(find).first
        }
        container = view
        node = try #require(find(view.viewTree.rootNode))
        self.model = model
        value = text
        focus()
    }

    private let model: TextValue
    var head: Int { (node as? TextFieldViewNode)?.selectionHead ?? (node as? TextEditorViewNode)?.selectionHead ?? -1 }
    func select(_ anchor: Int, _ head: Int) {
        if let field = node as? TextFieldViewNode { field.selectionAnchor = anchor; field.selectionHead = head }
        if let editor = node as? TextEditorViewNode { editor.selectionAnchor = anchor; editor.selectionHead = head }
    }
    func focus() { container.focusManager.focus(node) }
    func unfocus() { container.focusManager.focus(nil) }
    func replaceExternally(_ text: String) {
        model.text = text
        container.viewTree.rootNode.invalidateContent()
        container.layoutSubviews()
        value = model.text
    }
    func send(_ action: TextInputEvent.Action, _ text: String = "", cursor: Int = 1, start: Int = 0, end: Int = 0, session: TextInputEvent.Session? = nil) {
        container.onTextInputEvent(TextInputEvent(
            window: .empty, text: text, action: action, time: 0,
            session: session, cursorOffset: cursor, rangeStart: start, rangeEnd: end
        ))
        value = model.text
    }
}

@MainActor
private final class TextValue {
    var text: String
    init(_ text: String) { self.text = text }
}
