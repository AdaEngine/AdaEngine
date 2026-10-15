/// The token stream the lowerers and the schema parser walk, produced by the shared ``AdaScriptAnalysisLexer``.
///
/// It drops comments, numbers lines from 1, and gives a string token its unquoted, unescaped content.
struct Lexer {
    private let source: String

    init(source: String) {
        self.source = source
    }

    mutating func lex() -> [Token] {
        var lexer = AdaScriptAnalysisLexer(source: source)
        return lexer.lex().compactMap { token in
            let kind: Token.Kind
            switch token.kind {
            case .comment: return nil
            case .identifier: kind = .identifier
            case .number: kind = .number
            case .punctuation: kind = .punctuation
            case .string: kind = .string
            }
            return Token(
                endOffset: token.endOffset,
                kind: kind,
                line: token.range.start.line + 1,
                startOffset: token.startOffset,
                text: kind == .string ? AdaScriptAnnotationValueParser.unquoted(token.text) : token.text
            )
        }
    }
}
