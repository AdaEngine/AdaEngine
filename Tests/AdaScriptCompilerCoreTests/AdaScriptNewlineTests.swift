import AdaScriptCompilerCore
import Testing

@Suite("AdaScript newline handling")
struct AdaScriptNewlineTests {
    @Test(arguments: ["\n", "\r\n", "\r"])
    func commentsPreserveDeclarationsAndPositions(newline: String) throws {
        let source = [
            "// Привет 🌍",
            "@scriptable(id: \"test.newlines\")",
            "class Controller {",
            "    @export var title = \"Мир\";",
            "}"
        ].joined(separator: newline)
        var lexer = AdaScriptAnalysisLexer(source: source)
        let tokens = lexer.lex()
        let comment = try #require(tokens.first)
        #expect(comment.kind == .comment)
        #expect(comment.text == "// Привет 🌍")
        let annotation = try #require(tokens.first { $0.text == "@" })
        #expect(annotation.range.start.line == 1)
        #expect(annotation.range.start.utf16Column == 0)
        let declaration = try #require(tokens.first { $0.text == "class" })
        #expect(declaration.range.start.line == 2)
        #expect(Array(source)[annotation.startOffset] == "@")
        let schemas = try AdaScriptSchemaParser.parseScriptables(sources: [
            AdaScriptCompilerSource(path: "Controller.ada", source: source)
        ])
        #expect(schemas.map(\.id) == ["test.newlines"])
    }
}
