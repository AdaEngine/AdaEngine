@testable import GravityLanguageCore
import Testing

@Suite("AdaScript language lexer")
struct GravityLexerTests {
    private func lex(_ source: String) -> GravityLexResult {
        var lexer = GravityLexer(source: source)
        return lexer.lex()
    }

    private func messages(_ source: String) -> [String] {
        lex(source).diagnostics.map(\.message)
    }

    @Test("Tokens carry kinds, text and line/UTF-16 positions")
    func tokens() {
        let result = lex("var a = \"x\"; // done\nconst b = 12.5;")
        let kinds = result.tokens.map(\.kind)

        #expect(result.tokens.map(\.text) == ["var", "a", "=", "\"x\"", ";", "// done", "const", "b", "=", "12.5", ";"])
        #expect(kinds.first == .identifier)
        #expect(kinds.contains(.comment))
        #expect(result.tokens.first { $0.text == "const" }?.range.start == GravitySourcePosition(line: 1, utf16Column: 0))
    }

    @Test("A number keeps its exponent in one token")
    func exponents() {
        #expect(lex("1e-3 2.5E+4 7").tokens.map(\.text) == ["1e-3", "2.5E+4", "7"])
    }

    @Test("Balanced source has no diagnostics")
    func balanced() {
        #expect(messages("func f(a) { return [a, (a)]; }").isEmpty)
    }

    @Test("Unclosed delimiters are reported innermost first, after the rest of the file")
    func unclosed() {
        let result = lex("class A { func f( {")
        #expect(result.diagnostics.map(\.message) == ["Unclosed '{'", "Unclosed '('", "Unclosed '{'"])
        #expect(result.diagnostics[0].range.start.utf16Column == 18)
    }

    @Test("A closing delimiter without a match is reported where it is, in order with later problems")
    func unexpected() {
        #expect(messages("a ) b \"open") == ["Unexpected ')'", "Unterminated string literal"])
        #expect(messages("( ]") == ["Unexpected ']'", "Unclosed '('"])
    }

    @Test("Strings: escaped quotes keep the string open, both quote styles terminate")
    func strings() {
        #expect(messages(#"var a = "say \"hi\"";"#).isEmpty)
        #expect(messages("var a = 'ok';").isEmpty)
        #expect(messages(#"var a = "unterminated\""#) == ["Unterminated string literal"])
        #expect(messages("var a = \"line\nbreak\";").isEmpty)
    }

    @Test("Block comments nest; an unbalanced one covers the rest of the file")
    func blockComments() {
        #expect(messages("/* a /* b */ c */ var x;").isEmpty)
        let result = lex("var x; /* open /* nested */ still open")
        #expect(result.diagnostics.map(\.message) == ["Unterminated block comment"])
        #expect(result.diagnostics.first?.range.start == GravitySourcePosition(line: 0, utf16Column: 7))
        #expect(result.tokens.last?.kind == .comment)
    }

    @Test("Delimiters inside strings and comments are ignored")
    func delimitersInsideLiterals() {
        #expect(messages("var a = \"(\"; // )\n/* { */").isEmpty)
    }

    @Test("Unicode columns are UTF-16 offsets")
    func unicodeColumns() {
        let result = lex("var s = \"😀\"; )")
        let unexpected = result.diagnostics.first
        #expect(unexpected?.message == "Unexpected ')'")
        #expect(unexpected?.range.start.utf16Column == 14)
    }
}
