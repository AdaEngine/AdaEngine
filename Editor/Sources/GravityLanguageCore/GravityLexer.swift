import AdaScriptCompilerCore
import Foundation

struct GravityToken: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case comment
        case identifier
        case number
        case punctuation
        case string
    }

    var kind: Kind
    var text: String
    var range: GravitySourceRange
}

struct GravityLexResult: Sendable {
    var diagnostics: [GravityDiagnostic]
    var tokens: [GravityToken]
}

/// Language-tooling view of the shared AdaScript lexer: the same tokens the compiler sees, plus the
/// unterminated string/comment and unbalanced delimiter diagnostics an editor reports while typing.
struct GravityLexer {
    private let source: String

    init(source: String) {
        self.source = source
    }

    mutating func lex() -> GravityLexResult {
        var lexer = AdaScriptAnalysisLexer(source: source)
        let analysisTokens = lexer.lex()
        var diagnostics: [GravityDiagnostic] = []
        var delimiters: [AdaScriptAnalysisToken] = []
        for token in analysisTokens {
            switch token.kind {
            case .comment where Self.isUnterminatedBlockComment(token.text):
                diagnostics.append(GravityDiagnostic(message: "Unterminated block comment", range: token.range.gravityRange))
            case .string where !Self.isTerminatedString(token.text):
                diagnostics.append(GravityDiagnostic(message: "Unterminated string literal", range: token.range.gravityRange))
            case .punctuation:
                if let diagnostic = Self.balance(delimiter: token, stack: &delimiters) {
                    diagnostics.append(diagnostic)
                }
            case .comment, .identifier, .number, .string:
                break
            }
        }
        for opening in delimiters.reversed() {
            diagnostics.append(GravityDiagnostic(message: "Unclosed '\(opening.text)'", range: opening.range.gravityRange))
        }
        return GravityLexResult(diagnostics: diagnostics, tokens: analysisTokens.map(Self.gravityToken))
    }

    private static func gravityToken(_ token: AdaScriptAnalysisToken) -> GravityToken {
        let kind: GravityToken.Kind =
            switch token.kind {
            case .comment: .comment
            case .identifier: .identifier
            case .number: .number
            case .punctuation: .punctuation
            case .string: .string
            }
        return GravityToken(kind: kind, text: token.text, range: token.range.gravityRange)
    }

    /// Pushes an opening delimiter, or pops its match; returns the diagnostic for a closing one with no opening.
    private static func balance(delimiter token: AdaScriptAnalysisToken, stack: inout [AdaScriptAnalysisToken]) -> GravityDiagnostic? {
        switch token.text {
        case "(", "[", "{":
            stack.append(token)
            return nil
        case ")", "]", "}":
            let expectedOpening =
                switch token.text {
                case ")": "("
                case "]": "["
                default: "{"
                }
            if stack.last?.text == expectedOpening {
                stack.removeLast()
                return nil
            }
            return GravityDiagnostic(message: "Unexpected '\(token.text)'", range: token.range.gravityRange)
        default:
            return nil
        }
    }

    /// A `/* ... */` comment whose nested openings and closings do not balance by the end of the text.
    private static func isUnterminatedBlockComment(_ text: String) -> Bool {
        guard text.hasPrefix("/*") else {
            return false
        }
        var depth = 0
        var characters = Substring(text)
        while !characters.isEmpty {
            if characters.hasPrefix("/*") {
                depth += 1
                characters = characters.dropFirst(2)
            } else if characters.hasPrefix("*/") {
                depth -= 1
                characters = characters.dropFirst(2)
                if depth == 0 {
                    return false
                }
            } else {
                characters = characters.dropFirst()
            }
        }
        return depth != 0
    }

    /// A string token ends with its own unescaped closing quote.
    private static func isTerminatedString(_ text: String) -> Bool {
        guard let quote = text.first else {
            return false
        }
        var escaped = false
        for character in text.dropFirst() {
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == quote {
                return true
            }
        }
        return false
    }
}
