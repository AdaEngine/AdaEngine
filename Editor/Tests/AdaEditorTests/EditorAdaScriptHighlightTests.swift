@testable import AdaEditor
@_spi(AdaEngine) import AdaEngine
@_spi(Internal) @testable import AdaUI
import Math
import Testing

@MainActor @Suite(.serialized)
struct EditorAdaScriptHighlightTests {
    init() {
        if unsafe RenderEngine.shared == nil {
            unsafe RenderEngine.configurations.preferredBackend = .headless
            RenderWorldPlugin().setup(in: AppWorlds(main: World(name: "AdaScriptHighlightTests")))
        }
    }

    @Test("AdaScript editor colors annotations and member access with and without semantic tokens", arguments: [false, true])
    func annotationAndMemberColors(semantic: Bool) throws {
        let source = Self.source
        let palette = EditorCodeColorPalette.dark
        let model = EditorWorkbenchViewModel()
        var document = EditorTextDocument(
            id: "ada",
            title: "Director.ada",
            relativePath: "Director.ada",
            language: .ada,
            content: source,
            errorMessage: nil
        )
        if semantic {
            document.semanticTokens = EditorGravityLanguageService.semanticTokens(text: source)
        }
        model.open(.text(document))
        let view = makeView(document: document, model: model, palette: palette)
        let container = UIContainerView(rootView: view.theme(.adaEditor))
        container.frame = Rect(x: 0, y: 0, width: 900, height: 600)
        container.bounds.size = container.frame.size
        container.layoutIfNeeded()
        let node = try #require(editorNode(in: container.viewTree.rootNode))
        func color(line: Int, column: Int) -> Color? {
            node.tokenSpans.first {
                $0.line == line && $0.startColumn <= column && column < $0.startColumn + $0.length
            }?.color
        }
        #expect(color(line: 0, column: 0) == palette.keyword)
        #expect(color(line: 0, column: 1) == palette.keyword)
        #expect(color(line: 2, column: 4) == palette.keyword)
        #expect(color(line: 4, column: 21) == palette.type) // outer
        #expect(color(line: 4, column: 34) == palette.type) // moveX
        #expect(color(line: 5, column: 16) == palette.type) // world
        #expect(color(line: 5, column: 22) == palette.type) // commands
        #expect(color(line: 5, column: 31) == palette.type) // spawn
        #expect(color(line: 6, column: 14) == palette.type) // restart
        #expect(color(line: 7, column: 11) == palette.comment)
        #expect(color(line: 8, column: 21) == palette.string)
    }

    private func makeView(
        document: EditorTextDocument,
        model: EditorWorkbenchViewModel,
        palette: EditorCodeColorPalette
    ) -> EditorCodeFileView {
        EditorCodeFileView(
            document: document,
            text: model.textDocumentBinding(documentID: document.id),
            fontSize: 14,
            fontFamily: model.codeFontFamily,
            fontWeight: model.codeFontWeight,
            keywordFontWeight: model.keywordFontWeight,
            colorPalette: palette,
            onSourceHover: nil,
            onGoToDefinition: nil,
            onCompletionPosition: nil,
            onCompletionRequest: nil,
            onApplyCompletion: nil,
            onMoveCompletionSelection: nil,
            onAcceptCompletion: nil,
            onTextSelection: nil,
            onChatSelection: nil,
            sourceContextMenuItems: nil
        )
    }

    private static let source = """
        @scriptable(id: "game.director")
        class Director {
            @res var progress: Progress;
            func update(context: AdaScriptableContext) {
                if (progress.outer) input.moveX = 0.0;
                context.world.commands.spawn([]);
                input.restart ();
                // @res progress.outer input.restart()
                var label = "@res progress.outer input.restart()";
            }
        }
        """

    private func editorNode(in node: ViewNode) -> TextEditorViewNode? {
        if let editor = node as? TextEditorViewNode {
            return editor
        }
        return node.transientEnvironmentChildren.lazy.compactMap { editorNode(in: $0) }.first
    }
}
