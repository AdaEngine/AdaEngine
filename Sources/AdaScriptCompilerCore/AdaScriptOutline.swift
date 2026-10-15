/// A declaration found by the outline scan: a type, a member of a type, or a top-level function or variable.
public struct AdaScriptOutlineSymbol: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case `class`
        case constant
        case `enum`
        case function
        case method
        case property
        case `struct`
        case variable
    }

    public var isAsync: Bool
    /// A `static` property, whose name does not collide with an instance property of the same name.
    public var isStatic: Bool
    public var kind: Kind
    public var members: [AdaScriptOutlineSymbol]
    public var name: String
    /// A type spans from its keyword to its closing brace; any other symbol is its name token.
    public var range: AdaScriptSourceRange
    public var selectionRange: AdaScriptSourceRange

    public init(
        isAsync: Bool = false,
        isStatic: Bool = false,
        kind: Kind,
        members: [AdaScriptOutlineSymbol] = [],
        name: String,
        range: AdaScriptSourceRange,
        selectionRange: AdaScriptSourceRange? = nil
    ) {
        self.isAsync = isAsync
        self.isStatic = isStatic
        self.kind = kind
        self.members = members
        self.name = name
        self.range = range
        self.selectionRange = selectionRange ?? range
    }
}

/// A `class`, `struct` or `enum` and where its body starts and ends.
public struct AdaScriptOutlineType: Equatable, Hashable, Sendable {
    /// Annotations written before the keyword, in source order.
    public var annotations: [AdaScriptAnnotationSyntax]
    /// The start of the closing brace, or of the last token when the body is never closed.
    public var bodyEnd: AdaScriptSourcePosition
    /// The start of the opening brace.
    public var bodyStart: AdaScriptSourcePosition
    public var isTerminated: Bool
    public var symbol: AdaScriptOutlineSymbol

    public init(
        annotations: [AdaScriptAnnotationSyntax],
        bodyEnd: AdaScriptSourcePosition,
        bodyStart: AdaScriptSourcePosition,
        isTerminated: Bool,
        symbol: AdaScriptOutlineSymbol
    ) {
        self.annotations = annotations
        self.bodyEnd = bodyEnd
        self.bodyStart = bodyStart
        self.isTerminated = isTerminated
        self.symbol = symbol
    }
}

/// The declarations of a file, found by a scan that tolerates unfinished code: a type whose braces never
/// close runs to the end of the file, and a declaration needs only its keyword and a name.
public struct AdaScriptOutline: Equatable, Hashable, Sendable {
    /// Top-level functions and variables, outside any type body.
    public var globals: [AdaScriptOutlineSymbol]
    public var types: [AdaScriptOutlineType]

    public init(globals: [AdaScriptOutlineSymbol] = [], types: [AdaScriptOutlineType] = []) {
        self.globals = globals
        self.types = types
    }
}

/// Builds an ``AdaScriptOutline`` from non-comment tokens.
struct AdaScriptOutlineParser {
    private static let modifiers: Set<String> = ["static", "private", "public", "extern"]
    private static let typeKeywords: Set<String> = ["class", "enum", "struct"]

    private let annotationsByOffset: [Int: AdaScriptAnnotationSyntax]
    private let tokens: [AdaScriptAnalysisToken]

    init(tokens: [AdaScriptAnalysisToken], annotations: [AdaScriptAnnotationSyntax]) {
        self.annotationsByOffset = Dictionary(annotations.map { ($0.offsets.lowerBound, $0) }, uniquingKeysWith: { first, _ in first })
        self.tokens = tokens
    }

    func parse() -> AdaScriptOutline {
        let (types, bodies) = parseTypes()
        var excluded = Set<Int>()
        for body in bodies {
            excluded.formUnion(body)
        }
        let globals = parseDeclarations(in: tokens.indices, memberContext: false, excluded: excluded)
        return AdaScriptOutline(globals: globals, types: types)
    }

    // MARK: Types

    private func parseTypes() -> (types: [AdaScriptOutlineType], bodies: [ClosedRange<Int>]) {
        var types: [AdaScriptOutlineType] = []
        var bodies: [ClosedRange<Int>] = []
        var index = 0
        while index < tokens.count {
            guard
                let kind = typeKind(for: tokens[index].text),
                index + 1 < tokens.count, tokens[index + 1].kind == .identifier,
                let openIndex = nextToken("{", after: index + 1)
            else {
                index += 1
                continue
            }
            let nameIndex = index + 1
            let matchedClose = matchingCloseBrace(for: openIndex)
            let memberUpperBound = matchedClose ?? tokens.count
            let closeIndex = matchedClose ?? (tokens.count - 1)
            let members = parseDeclarations(in: (openIndex + 1)..<memberUpperBound, memberContext: true, excluded: [])
            let symbol = AdaScriptOutlineSymbol(
                kind: kind,
                members: members,
                name: tokens[nameIndex].text,
                range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[closeIndex].range.end),
                selectionRange: tokens[nameIndex].range
            )
            types.append(
                AdaScriptOutlineType(
                    annotations: annotations(before: index),
                    bodyEnd: tokens[closeIndex].range.start,
                    bodyStart: tokens[openIndex].range.start,
                    isTerminated: matchedClose != nil,
                    symbol: symbol
                )
            )
            bodies.append(openIndex...closeIndex)
            index = memberUpperBound
        }
        return (types, bodies)
    }

    // MARK: Declarations

    /// Functions, variables and constants at brace depth zero of `range`, skipping `excluded` token indices.
    private func parseDeclarations(in range: Range<Int>, memberContext: Bool, excluded: Set<Int>) -> [AdaScriptOutlineSymbol] {
        var braceDepth = 0
        var symbols: [AdaScriptOutlineSymbol] = []
        var index = range.lowerBound
        while index < range.upperBound {
            let token = tokens[index]
            if excluded.contains(index) {
                index += 1
                continue
            }
            if token.text == "{" {
                braceDepth += 1
                index += 1
                continue
            }
            if token.text == "}" {
                braceDepth = max(0, braceDepth - 1)
                index += 1
                continue
            }
            guard braceDepth == 0, index + 1 < range.upperBound, tokens[index + 1].kind == .identifier else {
                index += 1
                continue
            }
            if let symbol = declarationSymbol(at: index, memberContext: memberContext) {
                symbols.append(symbol)
            }
            index += 1
        }
        return symbols
    }

    private func declarationSymbol(at index: Int, memberContext: Bool) -> AdaScriptOutlineSymbol? {
        let kind: AdaScriptOutlineSymbol.Kind
        switch tokens[index].text {
        case "func":
            kind = memberContext ? .method : .function
        case "var":
            kind = memberContext ? .property : .variable
        case "const":
            kind = memberContext ? .property : .constant
        default:
            return nil
        }
        let nameToken = tokens[index + 1]
        return AdaScriptOutlineSymbol(
            isAsync: kind == .method || kind == .function ? index > 0 && tokens[index - 1].text == "async" : false,
            isStatic: kind != .method && kind != .function && hasModifier("static", before: index),
            kind: kind,
            name: nameToken.text,
            range: nameToken.range
        )
    }

    private func hasModifier(_ modifier: String, before index: Int) -> Bool {
        var cursor = index - 1
        while cursor >= 0, Self.modifiers.contains(tokens[cursor].text) {
            if tokens[cursor].text == modifier {
                return true
            }
            cursor -= 1
        }
        return false
    }

    // MARK: Annotations

    /// The annotations written before the declaration at `declarationIndex`, in source order.
    ///
    /// Walks backwards over `@name(...)` groups until a `;`, a `}` or another type keyword.
    private func annotations(before declarationIndex: Int) -> [AdaScriptAnnotationSyntax] {
        guard declarationIndex > 0 else {
            return []
        }
        var found: [AdaScriptAnnotationSyntax] = []
        var cursor = declarationIndex - 1
        var parenthesisDepth = 0
        while cursor >= 0 {
            let token = tokens[cursor]
            if token.text == ")" {
                parenthesisDepth += 1
            } else if token.text == "(" {
                parenthesisDepth = max(0, parenthesisDepth - 1)
            } else if parenthesisDepth == 0, token.kind == .identifier, cursor > 0, tokens[cursor - 1].text == "@" {
                if let annotation = annotationsByOffset[tokens[cursor - 1].startOffset] {
                    found.append(annotation)
                }
                cursor -= 1
            } else if parenthesisDepth == 0, token.text == ";" || token.text == "}" || Self.typeKeywords.contains(token.text) {
                break
            }
            cursor -= 1
        }
        return found.reversed()
    }

    // MARK: Token helpers

    private func typeKind(for text: String) -> AdaScriptOutlineSymbol.Kind? {
        switch text {
        case "class": .class
        case "enum": .enum
        case "struct": .struct
        default: nil
        }
    }

    private func nextToken(_ text: String, after index: Int) -> Int? {
        var candidate = index + 1
        while candidate < tokens.count {
            if tokens[candidate].text == text {
                return candidate
            }
            if tokens[candidate].text == ";" || tokens[candidate].text == "}" {
                return nil
            }
            candidate += 1
        }
        return nil
    }

    private func matchingCloseBrace(for openIndex: Int) -> Int? {
        var depth = 0
        for index in openIndex..<tokens.count {
            if tokens[index].text == "{" {
                depth += 1
            } else if tokens[index].text == "}" {
                depth -= 1
                if depth == 0 {
                    return index
                }
            }
        }
        return nil
    }
}
