/// Rewrites the component references of `@query(...)` into forms the Gravity annotation grammar accepts.
///
/// Gravity annotation arguments are symbols, strings, numbers, booleans, null, and lists. A query may also
/// name a component by qualified path and give it an alias, `Game.Health as health`, which is not one of
/// those. Each such reference becomes the string `"Game.Health as health"`; a plain `Health` is left alone.
public enum AdaScriptQueryLowerer {
    public static func lower(source: String) -> String {
        var lexer = Lexer(source: source)
        let tokens = lexer.lex()
        var characters = Array(source)
        var edits: [(range: Range<Int>, text: String)] = []

        var index = 0
        while index + 2 < tokens.count {
            guard tokens[index].text == "@", tokens[index + 1].text == "query", tokens[index + 2].text == "(",
                let close = closing(openingAt: index + 2, tokens: tokens) else {
                index += 1
                continue
            }
            lowerArguments(in: (index + 3)..<close, tokens: tokens, edits: &edits)
            index = close + 1
        }
        guard !edits.isEmpty else {
            return source
        }
        for edit in edits.sorted(by: { $0.range.lowerBound > $1.range.lowerBound }) {
            characters.replaceSubrange(edit.range, with: Array(edit.text))
        }
        return String(characters)
    }

    private static func lowerArguments(in range: Range<Int>, tokens: [Token], edits: inout [(range: Range<Int>, text: String)]) {
        for argument in splitTopLevel(range, tokens: tokens) {
            var start = argument.lowerBound
            // `label: value` — the value is what may need lowering.
            if start + 1 < argument.upperBound, tokens[start].kind == .identifier, tokens[start + 1].text == ":" {
                start += 2
            }
            guard start < argument.upperBound else { continue }
            if tokens[start].text == "[", let close = closing(openingAt: start, tokens: tokens), close < argument.upperBound {
                for item in splitTopLevel((start + 1)..<close, tokens: tokens) {
                    lowerReference(item, tokens: tokens, edits: &edits)
                }
            } else {
                lowerReference(start..<argument.upperBound, tokens: tokens, edits: &edits)
            }
        }
    }

    /// Replaces `A.B.C [as d]` with a string literal when it is qualified or aliased.
    private static func lowerReference(_ range: Range<Int>, tokens: [Token], edits: inout [(range: Range<Int>, text: String)]) {
        guard !range.isEmpty, tokens[range.lowerBound].kind == .identifier else { return }
        var cursor = range.lowerBound + 1
        var text = tokens[range.lowerBound].text
        var isQualified = false
        while cursor + 1 < range.upperBound, tokens[cursor].text == ".", tokens[cursor + 1].kind == .identifier {
            text += "." + tokens[cursor + 1].text
            isQualified = true
            cursor += 2
        }
        var isAliased = false
        if cursor + 1 < range.upperBound, tokens[cursor].text == "as", tokens[cursor + 1].kind == .identifier {
            text += " as " + tokens[cursor + 1].text
            isAliased = true
            cursor += 2
        }
        guard cursor == range.upperBound, isQualified || isAliased else { return }
        edits.append((tokens[range.lowerBound].startOffset..<tokens[range.upperBound - 1].endOffset, "\"\(text)\""))
    }

    private static func closing(openingAt open: Int, tokens: [Token]) -> Int? {
        let opening = tokens[open].text
        let closing = opening == "(" ? ")" : "]"
        var depth = 0
        for index in open..<tokens.count {
            if tokens[index].text == opening { depth += 1 }
            if tokens[index].text == closing {
                depth -= 1
                if depth == 0 { return index }
            }
        }
        return nil
    }

    private static func splitTopLevel(_ range: Range<Int>, tokens: [Token]) -> [Range<Int>] {
        var parts: [Range<Int>] = []
        var start = range.lowerBound
        var depth = 0
        for index in range {
            switch tokens[index].text {
            case "(", "[": depth += 1
            case ")", "]": depth -= 1
            case "," where depth == 0:
                if index > start { parts.append(start..<index) }
                start = index + 1
            default: break
            }
        }
        if range.upperBound > start { parts.append(start..<range.upperBound) }
        return parts
    }
}
