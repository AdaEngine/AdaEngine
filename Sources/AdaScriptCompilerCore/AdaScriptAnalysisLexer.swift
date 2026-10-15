/// One lexical token of AdaScript source with its character offsets and line/UTF-16 position.
public struct AdaScriptAnalysisToken: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case comment
        case identifier
        case number
        case punctuation
        case string
    }

    public var endOffset: Int
    public var kind: Kind
    public var range: AdaScriptSourceRange
    public var startOffset: Int
    public var text: String

    public init(endOffset: Int, kind: Kind, range: AdaScriptSourceRange, startOffset: Int, text: String) {
        self.endOffset = endOffset
        self.kind = kind
        self.range = range
        self.startOffset = startOffset
        self.text = text
    }
}

/// The one lexer for AdaScript source, shared by the compiler analysis and the Editor's language tooling.
public struct AdaScriptAnalysisLexer {
    private let source: String
    private var index: String.Index
    private var line = 0
    private var offset = 0
    private var utf16Column = 0
    private var tokens: [AdaScriptAnalysisToken] = []

    public init(source: String) {
        self.source = source
        self.index = source.startIndex
    }

    public mutating func lex() -> [AdaScriptAnalysisToken] {
        while let character = currentCharacter {
            if character.isWhitespace {
                advance()
            } else if character == "/", peekCharacter() == "/" {
                lexLineComment()
            } else if character == "/", peekCharacter() == "*" {
                lexBlockComment()
            } else if character == "\"" || character == "'" {
                lexString(quote: character)
            } else if isIdentifierStart(character) {
                lexIdentifier()
            } else if character.isNumber {
                lexNumber()
            } else {
                lexPunctuation()
            }
        }
        return tokens
    }

    private var currentCharacter: Character? {
        index < source.endIndex ? source[index] : nil
    }

    private var position: AdaScriptSourcePosition {
        AdaScriptSourcePosition(line: line, utf16Column: utf16Column)
    }

    private func peekCharacter() -> Character? {
        guard index < source.endIndex else {
            return nil
        }
        let nextIndex = source.index(after: index)
        return nextIndex < source.endIndex ? source[nextIndex] : nil
    }

    private mutating func advance() {
        guard let character = currentCharacter else {
            return
        }
        index = source.index(after: index)
        offset += 1
        if character == "\n" {
            line += 1
            utf16Column = 0
        } else {
            utf16Column += String(character).utf16.count
        }
    }

    private mutating func lexLineComment() {
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        advance()
        advance()
        while let character = currentCharacter, character != "\n" {
            advance()
        }
        appendToken(kind: .comment, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func lexBlockComment() {
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        var depth = 0
        while currentCharacter != nil {
            if currentCharacter == "/", peekCharacter() == "*" {
                depth += 1
                advance()
                advance()
            } else if currentCharacter == "*", peekCharacter() == "/" {
                depth -= 1
                advance()
                advance()
                if depth == 0 {
                    break
                }
            } else {
                advance()
            }
        }
        appendToken(kind: .comment, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func lexString(quote: Character) {
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        var escaped = false
        advance()
        while let character = currentCharacter {
            advance()
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == quote {
                break
            }
        }
        appendToken(kind: .string, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func lexIdentifier() {
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        while let character = currentCharacter, isIdentifierContinuation(character) {
            advance()
        }
        appendToken(kind: .identifier, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func lexNumber() {
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        while let character = currentCharacter, character.isNumber || character == "." || character == "_" {
            advance()
        }
        if let character = currentCharacter, character == "e" || character == "E" {
            advance()
            if let sign = currentCharacter, sign == "+" || sign == "-" {
                advance()
            }
            while let digit = currentCharacter, digit.isNumber {
                advance()
            }
        }
        appendToken(kind: .number, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func lexPunctuation() {
        guard currentCharacter != nil else {
            return
        }
        let startIndex = index
        let startOffset = offset
        let startPosition = position
        advance()
        appendToken(kind: .punctuation, from: startIndex, offset: startOffset, position: startPosition)
    }

    private mutating func appendToken(
        kind: AdaScriptAnalysisToken.Kind,
        from startIndex: String.Index,
        offset startOffset: Int,
        position startPosition: AdaScriptSourcePosition
    ) {
        tokens.append(
            AdaScriptAnalysisToken(
                endOffset: offset,
                kind: kind,
                range: AdaScriptSourceRange(start: startPosition, end: position),
                startOffset: startOffset,
                text: String(source[startIndex..<index])
            )
        )
    }

    private func isIdentifierStart(_ character: Character) -> Bool {
        character == "_" || character.isLetter
    }

    private func isIdentifierContinuation(_ character: Character) -> Bool {
        isIdentifierStart(character) || character.isNumber
    }
}
