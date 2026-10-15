/// The shape of a constant after `=` in a field, parameter or variable declaration, before any type is applied.
///
/// The syntax tree only records what was written. Whether `Vector3(1, 2)` suits a `Vector3` field, or `Mode.idle`
/// names a real case, is decided by the consumer that knows the declared type.
public enum AdaScriptDefaultValue: Equatable, Hashable, Sendable {
    case bool(Bool)
    /// `Vector3(1, 2, 3)` or `[1, 2, 3]` (`callee` is `nil`). A component that is not a number is `nil`.
    /// `isClosed` is `false` when the closing `)` or `]` is missing.
    case construction(callee: String?, components: [String?], isClosed: Bool)
    /// `Type.member`, for example `Color.white`, `Vector3.ZERO` or `Mode.idle`.
    case member(base: String, member: String)
    /// A bare name such as `null`, or a type name written without arguments.
    case name(String)
    /// Nothing follows the `=`.
    case missing
    /// The number as written, including a leading `-`.
    case number(String)
    /// The string content without quotes.
    case string(String)
    /// Something that is not a constant this syntax models.
    case unsupported
}

/// One `= value` that follows a name, with the source offsets it covers.
public struct AdaScriptDefaultValueSyntax: Equatable, Hashable, Sendable {
    /// Offset of the `=` token, which identifies the declaration this value belongs to.
    public var equalsOffset: Int
    /// Offsets covered by the value tokens. Empty for ``AdaScriptDefaultValue/missing`` and ``AdaScriptDefaultValue/unsupported``.
    public var offsets: Range<Int>
    public var value: AdaScriptDefaultValue

    public init(equalsOffset: Int, offsets: Range<Int>, value: AdaScriptDefaultValue) {
        self.equalsOffset = equalsOffset
        self.offsets = offsets
        self.value = value
    }
}

/// Finds every default value in a token stream: each `=` that follows an identifier and is not part of a comparison.
struct AdaScriptDefaultValueParser {
    private let tokens: [AdaScriptAnalysisToken]

    init(tokens: [AdaScriptAnalysisToken]) {
        self.tokens = tokens
    }

    func parseAll() -> [AdaScriptDefaultValueSyntax] {
        tokens.indices.compactMap { index in
            isDeclarationEquals(at: index) ? parse(afterEqualsAt: index) : nil
        }
    }

    private func isDeclarationEquals(at index: Int) -> Bool {
        guard tokens[index].text == "=", index > 0, tokens[index - 1].kind == .identifier else {
            return false
        }
        // `==` is lexed as two adjacent `=` tokens.
        return !(index + 1 < tokens.count && tokens[index + 1].text == "=" && tokens[index + 1].startOffset == tokens[index].endOffset)
    }

    private func parse(afterEqualsAt equalsIndex: Int) -> AdaScriptDefaultValueSyntax {
        let equalsOffset = tokens[equalsIndex].startOffset
        let start = equalsIndex + 1
        func result(_ value: AdaScriptDefaultValue, through last: Int) -> AdaScriptDefaultValueSyntax {
            AdaScriptDefaultValueSyntax(equalsOffset: equalsOffset, offsets: tokens[start].startOffset..<tokens[last].endOffset, value: value)
        }
        func empty(_ value: AdaScriptDefaultValue) -> AdaScriptDefaultValueSyntax {
            AdaScriptDefaultValueSyntax(equalsOffset: equalsOffset, offsets: 0..<0, value: value)
        }
        guard start < tokens.count else {
            return empty(.missing)
        }
        let token = tokens[start]
        switch token.kind {
        case .string:
            return result(.string(AdaScriptAnnotationValueParser.unquoted(token.text)), through: start)
        case .number:
            return result(.number(token.text), through: start)
        case .comment:
            return empty(.unsupported)
        case .identifier:
            return parseNamed(startingAt: start, equalsOffset: equalsOffset)
        case .punctuation:
            if token.text == "-", start + 1 < tokens.count, tokens[start + 1].kind == .number {
                return result(.number("-" + tokens[start + 1].text), through: start + 1)
            }
            if token.text == "[" {
                return parseConstruction(callee: nil, openAt: start, firstIndex: start, equalsOffset: equalsOffset)
            }
            return empty(.unsupported)
        }
    }

    private func parseNamed(startingAt start: Int, equalsOffset: Int) -> AdaScriptDefaultValueSyntax {
        let token = tokens[start]
        func result(_ value: AdaScriptDefaultValue, through last: Int) -> AdaScriptDefaultValueSyntax {
            AdaScriptDefaultValueSyntax(equalsOffset: equalsOffset, offsets: token.startOffset..<tokens[last].endOffset, value: value)
        }
        switch token.text {
        case "true":
            return result(.bool(true), through: start)
        case "false":
            return result(.bool(false), through: start)
        default:
            break
        }
        if start + 2 < tokens.count, tokens[start + 1].text == ".", tokens[start + 2].kind == .identifier {
            return result(.member(base: token.text, member: tokens[start + 2].text), through: start + 2)
        }
        if start + 1 < tokens.count, tokens[start + 1].text == "(" {
            return parseConstruction(callee: token.text, openAt: start + 1, firstIndex: start, equalsOffset: equalsOffset)
        }
        return result(.name(token.text), through: start)
    }

    /// Reads `(a, -b, c)` or `[a, b, c]` whose opening token is at `openIndex`.
    private func parseConstruction(callee: String?, openAt openIndex: Int, firstIndex: Int, equalsOffset: Int) -> AdaScriptDefaultValueSyntax {
        let closer = tokens[openIndex].text == "(" ? ")" : "]"
        var components: [String?] = []
        var cursor = openIndex + 1
        var last = openIndex
        var isClosed = false
        scan: while cursor < tokens.count {
            if tokens[cursor].text == closer {
                isClosed = true
                last = cursor
                break scan
            }
            var sign = ""
            if tokens[cursor].text == "-" {
                sign = "-"
                cursor += 1
            }
            guard cursor < tokens.count, tokens[cursor].kind == .number, Double(tokens[cursor].text) != nil else {
                components.append(nil)
                break scan
            }
            components.append(sign + tokens[cursor].text)
            last = cursor
            cursor += 1
            guard cursor < tokens.count, tokens[cursor].text == "," else {
                if cursor < tokens.count, tokens[cursor].text == closer {
                    isClosed = true
                    last = cursor
                }
                break scan
            }
            last = cursor
            cursor += 1
        }
        return AdaScriptDefaultValueSyntax(
            equalsOffset: equalsOffset,
            offsets: tokens[firstIndex].startOffset..<tokens[last].endOffset,
            value: .construction(callee: callee, components: components, isClosed: isClosed)
        )
    }
}
