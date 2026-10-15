/// Parses the argument list of one annotation into labelled literal values, once, for every consumer.
struct AdaScriptAnnotationValueParser {
    struct Result {
        var problem: String?
        var values: [AdaScriptAnnotationArgument]
    }

    private let annotation: String
    private let end: Int
    private var index: Int
    private let tokens: [AdaScriptAnalysisToken]

    /// - Parameter range: the token indices between the annotation's parentheses.
    init(annotation: String, tokens: [AdaScriptAnalysisToken], range: Range<Int>) {
        self.annotation = annotation
        self.end = range.upperBound
        self.index = range.lowerBound
        self.tokens = tokens
    }

    mutating func parse() -> Result {
        var values: [AdaScriptAnnotationArgument] = []
        do {
            while index < end {
                if tokens[index].kind == .identifier, index + 1 < end, tokens[index + 1].text == ":" {
                    let label = tokens[index].text
                    index += 2
                    values.append(AdaScriptAnnotationArgument(label: label, value: try parseValue(label: label)))
                } else {
                    values.append(AdaScriptAnnotationArgument(value: try parseValue(label: "value")))
                }
                guard index < end, tokens[index].text == "," else {
                    break
                }
                index += 1
            }
        } catch {
            return Result(problem: error.message, values: values)
        }
        if index < end {
            return Result(problem: "unterminated @\(annotation) annotation", values: values)
        }
        return Result(problem: nil, values: values)
    }

    private struct Failure: Error {
        var message: String
    }

    private mutating func parseValue(label: String) throws(Failure) -> AdaScriptAnnotationValue {
        if index < end, tokens[index].text == "[" {
            return .list(try parseList(label: label))
        }
        guard index < end else {
            throw Failure(message: "missing value for @\(annotation) \(label)")
        }
        let token = tokens[index]
        index += 1
        switch token.kind {
        case .string:
            return .string(Self.unquoted(token.text))
        case .number:
            return .number(token.text)
        case .identifier where token.text == "true":
            return .bool(true)
        case .identifier where token.text == "false":
            return .bool(false)
        case .identifier:
            return .identifier(parseQualifiedName(startingWith: token.text))
        case .comment, .punctuation:
            throw Failure(message: "unsupported value for @\(annotation) \(label)")
        }
    }

    /// `Game.Health` and `Game.Health as health` are query component references.
    private mutating func parseQualifiedName(startingWith first: String) -> String {
        var text = first
        while index + 1 < end, tokens[index].text == ".", tokens[index + 1].kind == .identifier {
            text += "." + tokens[index + 1].text
            index += 2
        }
        if index + 1 < end, tokens[index].kind == .identifier, tokens[index].text == "as", tokens[index + 1].kind == .identifier {
            text += " as " + tokens[index + 1].text
            index += 2
        }
        return text
    }

    private mutating func parseList(label: String) throws(Failure) -> [AdaScriptAnnotationValue] {
        index += 1
        var values: [AdaScriptAnnotationValue] = []
        while index < end, tokens[index].text != "]" {
            values.append(try parseValue(label: label))
            guard index < end, tokens[index].text == "," else {
                break
            }
            index += 1
        }
        guard index < end, tokens[index].text == "]" else {
            throw Failure(message: "unterminated list for @\(annotation) \(label)")
        }
        index += 1
        return values
    }

    /// The string content without its quotes; a backslash makes the next character literal.
    static func unquoted(_ literal: String) -> String {
        var characters = Array(literal)
        guard let quote = characters.first, quote == "\"" || quote == "'" else {
            return literal
        }
        characters.removeFirst()
        if characters.last == quote {
            characters.removeLast()
        }
        var result = ""
        var escaped = false
        for character in characters {
            if escaped || character != "\\" {
                result.append(character)
                escaped = false
            } else {
                escaped = true
            }
        }
        return result
    }
}
