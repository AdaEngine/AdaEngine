import Foundation

struct Lexer {
    private let source: String
    private var index: String.Index

    init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    mutating func lex() -> [Token] {
        var tokens: [Token] = []
        while index < source.endIndex {
            if source[index].isWhitespace {
                advance()
            } else if hasPrefix("//") {
                while index < source.endIndex, source[index] != "\n" { advance() }
            } else if hasPrefix("/*") {
                advance(2)
                while index < source.endIndex, !hasPrefix("*/") { advance() }
                advance(2)
            } else if source[index] == "\"" {
                tokens.append(Token(kind: .string, text: lexString()))
            } else if source[index].isLetter || source[index] == "_" {
                tokens.append(Token(kind: .identifier, text: lexIdentifier()))
            } else if source[index].isNumber {
                tokens.append(Token(kind: .number, text: lexNumber()))
            } else {
                let character = source[index]
                advance()
                tokens.append(Token(kind: .punctuation, text: String(character)))
            }
        }
        return tokens
    }

    private mutating func lexString() -> String {
        advance()
        var result = ""
        while index < source.endIndex, source[index] != "\"" {
            if source[index] == "\\" {
                advance()
            }
            guard index < source.endIndex else { break }
            result.append(source[index])
            advance()
        }
        advance()
        return result
    }

    private mutating func lexIdentifier() -> String {
        let start = index
        while index < source.endIndex, source[index].isLetter || source[index].isNumber || source[index] == "_" { advance() }
        return String(source[start..<index])
    }

    private mutating func lexNumber() -> String {
        let start = index
        while index < source.endIndex, source[index].isNumber || ".eE+-".contains(source[index]) { advance() }
        return String(source[start..<index])
    }

    private func hasPrefix(_ value: String) -> Bool { source[index...].hasPrefix(value) }

    private mutating func advance(_ distance: Int = 1) {
        index = source.index(index, offsetBy: distance, limitedBy: source.endIndex) ?? source.endIndex
    }
}
