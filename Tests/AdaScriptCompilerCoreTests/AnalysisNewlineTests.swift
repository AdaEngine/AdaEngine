import AdaScriptCompilerCore
import Testing

@Suite("AdaScript source newlines")
struct AnalysisNewlineTests {
    @Test("Comments and diagnostics preserve source lines for LF, CRLF and CR", arguments: ["\n", "\r\n", "\r"])
    func lineEndings(_ newline: String) throws {
        let source = ["// Робот идёт к цели", "func greeting() {", "    return \"Привет\";", "}"].joined(separator: newline)
        var lexer = AdaScriptAnalysisLexer(source: source)
        let tokens = lexer.lex()
        let function = try #require(tokens.first { $0.text == "func" })
        let result = try #require(tokens.first { $0.text == "return" })
        #expect(function.range.start.line == 1)
        #expect(function.range.start.utf16Column == 0)
        #expect(result.range.start.line == 2)
        #expect(result.range.start.utf16Column == 4)
        #expect(AdaScriptAnalyzer.analyze(source: source).typeIssues.isEmpty)
    }
}
