import Foundation
struct AdaScriptParsedBinding: Sendable {
    var initializerRange: Range<Int>?
    var syntax: AdaScriptBindingSyntax
}

struct AdaScriptParsedFunction: Sendable {
    var bodyRange: Range<Int>?
    var syntax: AdaScriptFunctionSyntax
}

struct AdaScriptParsedType: Sendable {
    var bindings: [AdaScriptParsedBinding]
    var functions: [AdaScriptParsedFunction]
    var syntax: AdaScriptTypeSyntax
}

struct AdaScriptParsedDocument: Sendable {
    var bindings: [AdaScriptParsedBinding]
    var functions: [AdaScriptParsedFunction]
    var syntax: AdaScriptSyntaxTree
    var tokens: [AdaScriptAnalysisToken]
    var types: [AdaScriptParsedType]
}

struct AdaScriptSyntaxParser {
    private static let declarationModifiers: Set<String> = ["async", "extern", "private", "public", "static"]

    private let path: String
    private let tokens: [AdaScriptAnalysisToken]

    init(source: String, path: String) {
        var lexer = AdaScriptAnalysisLexer(source: source)
        self.tokens = lexer.lex().filter { $0.kind != .comment }
        self.path = path
    }

    func parse() -> AdaScriptParsedDocument {
        let parsed = parseDeclarations(in: tokens.indices)
        let imports = parseImports()
        let syntax = AdaScriptSyntaxTree(
            annotationUses: parseAnnotationUses(),
            annotations: parseAllAnnotations(),
            bindings: parsed.bindings.map(\.syntax),
            declaredNames: declaredNames(),
            defaultValues: AdaScriptDefaultValueParser(tokens: tokens).parseAll(),
            enums: parseEnums(),
            functions: parsed.functions.map(\.syntax),
            importDiagnostics: imports.diagnostics,
            importUses: parseImportUses(imports.declarations),
            imports: imports.declarations,
            isStrict: hasFileStrictAnnotation,
            path: path,
            references: nameReferences(excluding: imports.declarations.map(\.offsets)),
            tests: parsed.tests,
            types: parsed.types.map(\.syntax),
            visibilityModifierOffsets: topLevelVisibilityModifiers()
        )
        return AdaScriptParsedDocument(
            bindings: parsed.bindings,
            functions: parsed.functions,
            syntax: syntax,
            tokens: tokens,
            types: parsed.types
        )
    }

    private var hasFileStrictAnnotation: Bool {
        var braceDepth = 0
        for index in tokens.indices {
            if tokens[index].text == "{" {
                braceDepth += 1
            } else if tokens[index].text == "}" {
                braceDepth = max(0, braceDepth - 1)
            } else if braceDepth == 0, tokens[index].text == "@", index + 1 < tokens.count,
                tokens[index + 1].text == "strict" {
                return true
            }
        }
        return false
    }

    private func parseDeclarations(in range: Range<Int>) -> ParsedDeclarations {
        var result = ParsedDeclarations()
        var index = range.lowerBound
        while index < range.upperBound {
            let prefix = declarationPrefix(at: index, upperBound: range.upperBound)
            let declarationIndex = prefix.nextIndex
            guard declarationIndex < range.upperBound else {
                break
            }

            switch tokens[declarationIndex].text {
            case "class", "enum", "struct":
                guard let parsed = parseType(
                    at: declarationIndex,
                    annotations: prefix.annotations,
                    visibility: prefix.isPrivate ? .private : .public,
                    upperBound: range.upperBound
                ) else {
                    index += 1
                    continue
                }
                result.types.append(parsed.value)
                index = parsed.nextIndex
            case "func":
                guard let parsed = parseFunction(
                    at: declarationIndex,
                    annotations: prefix.annotations,
                    isAsync: prefix.isAsync,
                    visibility: prefix.isPrivate ? .private : .public,
                    upperBound: range.upperBound
                ) else {
                    index += 1
                    continue
                }
                result.functions.append(parsed.value)
                if let annotation = prefix.annotations.first(where: { $0.name == "test" }) {
                    result.tests.append(
                        testSyntax(
                            for: parsed.value.syntax,
                            annotation: annotation,
                            displayName: testDisplayName(from: prefix.startIndex, to: prefix.nextIndex),
                            offsets: tokens[prefix.startIndex].startOffset..<tokens[parsed.nextIndex - 1].endOffset
                        )
                    )
                }
                index = parsed.nextIndex
            case "const", "var":
                guard let parsed = parseBinding(
                    at: declarationIndex,
                    annotations: prefix.annotations,
                    visibility: prefix.isPrivate ? .private : .public,
                    upperBound: range.upperBound
                ) else {
                    index += 1
                    continue
                }
                result.bindings.append(parsed.value)
                index = parsed.nextIndex
            default:
                index += 1
            }
        }
        return result
    }

    private func testSyntax(
        for function: AdaScriptFunctionSyntax,
        annotation: AdaScriptAnnotationSyntax,
        displayName: String?,
        offsets: Range<Int>
    ) -> AdaScriptTestSyntax {
        AdaScriptTestSyntax(
            annotationRange: annotation.range,
            displayName: displayName ?? function.name,
            isAsync: function.isAsync,
            name: function.name,
            offsets: offsets,
            parameterCount: function.parameters.count,
            range: function.range
        )
    }

    /// The string in `@test("…")`, which `AdaScriptAnnotationSyntax.arguments` drops because it keeps identifiers only.
    private func testDisplayName(from start: Int, to end: Int) -> String? {
        guard end - start >= 4 else {
            return nil
        }
        for index in start..<(end - 3)
        where tokens[index].text == "@" && tokens[index + 1].text == "test" && tokens[index + 2].text == "(" && tokens[index + 3].kind == .string {
            let literal = tokens[index + 3].text
            return literal.count >= 2 ? String(literal.dropFirst().dropLast()) : nil
        }
        return nil
    }

    private func declarationPrefix(at index: Int, upperBound: Int) -> DeclarationPrefix {
        var annotations: [AdaScriptAnnotationSyntax] = []
        var cursor = index
        var isAsync = false
        var isPrivate = false
        while cursor < upperBound {
            if tokens[cursor].text == "@", let parsed = parseAnnotation(at: cursor, upperBound: upperBound) {
                annotations.append(parsed.value)
                cursor = parsed.nextIndex
                continue
            }
            if Self.declarationModifiers.contains(tokens[cursor].text) {
                isAsync = isAsync || tokens[cursor].text == "async"
                isPrivate = isPrivate || tokens[cursor].text == "private"
                cursor += 1
                continue
            }
            break
        }
        return DeclarationPrefix(annotations: annotations, isAsync: isAsync, isPrivate: isPrivate, nextIndex: cursor, startIndex: index)
    }

    private func parseAnnotation(
        at index: Int,
        upperBound: Int
    ) -> (value: AdaScriptAnnotationSyntax, nextIndex: Int)? {
        guard index + 1 < upperBound, tokens[index + 1].kind == .identifier else {
            return nil
        }
        let nameToken = tokens[index + 1]
        var arguments: [String] = []
        var endIndex = index + 1
        var problem: String?
        var values: [AdaScriptAnnotationArgument] = []
        if index + 2 < upperBound, tokens[index + 2].text == "(" {
            if let closeIndex = matchingIndex(openingAt: index + 2, opening: "(", closing: ")", upperBound: upperBound) {
                arguments = nameToken.text == "query"
                    ? queryArguments(in: (index + 3)..<closeIndex)
                    : annotationArguments(in: (index + 3)..<closeIndex)
                var valueParser = AdaScriptAnnotationValueParser(annotation: nameToken.text, tokens: tokens, range: (index + 3)..<closeIndex)
                let parsed = valueParser.parse()
                values = parsed.values
                problem = parsed.problem
                endIndex = closeIndex
            } else {
                problem = "unterminated @\(nameToken.text) annotation"
            }
        }
        return (
            AdaScriptAnnotationSyntax(
                arguments: arguments,
                name: nameToken.text,
                offsets: tokens[index].startOffset..<tokens[endIndex].endOffset,
                problem: problem,
                range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[endIndex].range.end),
                values: values
            ),
            endIndex + 1
        )
    }

    /// Fetched components of a `@query`, in declaration order, as `Short` or `Short as alias`. Qualified
    /// names keep their last segment; `optional:` components are fetched too, so they are included.
    private func queryArguments(in range: Range<Int>) -> [String] {
        func entry(from parts: Range<Int>) -> String? {
            guard !parts.isEmpty else { return nil }
            if tokens[parts.lowerBound].kind == .string {
                let text = tokens[parts.lowerBound].text.dropFirst().dropLast()
                let pieces = text.components(separatedBy: " as ")
                guard let path = pieces.first, let short = path.split(separator: ".").last else { return nil }
                return pieces.count > 1 ? "\(short) as \(pieces[1])" : String(short)
            }
            let identifiers = parts.filter { tokens[$0].kind == .identifier }.map { tokens[$0].text }
            guard !identifiers.isEmpty else { return nil }
            if let asIndex = identifiers.firstIndex(of: "as"), asIndex > 0, asIndex + 1 < identifiers.count {
                return "\(identifiers[asIndex - 1]) as \(identifiers[asIndex + 1])"
            }
            return identifiers.last
        }
        var result: [String] = []
        for argument in splitTopLevel(range, separator: ",") {
            if let colon = firstTopLevelToken(":", in: argument) {
                guard tokens[argument.lowerBound].text == "optional" else { continue }
                var values = (colon + 1)..<argument.upperBound
                if values.first.map({ tokens[$0].text == "[" }) == true, values.count >= 2 {
                    values = (values.lowerBound + 1)..<(values.upperBound - 1)
                }
                result += splitTopLevel(values, separator: ",").compactMap(entry)
            } else if let value = entry(from: argument) {
                result.append(value)
            }
        }
        return result
    }

    private func annotationArguments(in range: Range<Int>) -> [String] {
        splitTopLevel(range, separator: ",").flatMap { argumentRange -> [String] in
            guard firstTopLevelToken(":", in: argumentRange) == nil else {
                return []
            }
            return argumentRange.compactMap { index in
                tokens[index].kind == .identifier ? tokens[index].text : nil
            }
        }
    }

    private func parseType(
        at index: Int,
        annotations: [AdaScriptAnnotationSyntax],
        visibility: AdaScriptDeclarationVisibility,
        upperBound: Int
    ) -> (value: AdaScriptParsedType, nextIndex: Int)? {
        guard
            index + 1 < upperBound,
            tokens[index + 1].kind == .identifier,
            let openIndex = nextToken("{", after: index + 1, upperBound: upperBound),
            let closeIndex = matchingIndex(openingAt: openIndex, opening: "{", closing: "}", upperBound: upperBound)
        else {
            return nil
        }
        let name = tokens[index + 1].text
        let members = parseDeclarations(in: (openIndex + 1)..<closeIndex)
        let kind: AdaScriptTypeSyntax.Kind =
            switch tokens[index].text {
            case "class": .class
            case "enum": .enum
            default: .struct
            }
        let syntax = AdaScriptTypeSyntax(
            annotations: annotations,
            bindings: members.bindings.map(\.syntax),
            functions: members.functions.map(\.syntax),
            kind: kind,
            name: name,
            range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[closeIndex].range.end),
            visibility: visibility
        )
        return (
            AdaScriptParsedType(
                bindings: members.bindings,
                functions: members.functions,
                syntax: syntax
            ),
            closeIndex + 1
        )
    }

    private func parseFunction(
        at index: Int,
        annotations: [AdaScriptAnnotationSyntax],
        isAsync: Bool,
        visibility: AdaScriptDeclarationVisibility,
        upperBound: Int
    ) -> (value: AdaScriptParsedFunction, nextIndex: Int)? {
        guard
            index + 2 < upperBound,
            tokens[index + 1].kind == .identifier,
            let openParenthesis = nextToken("(", after: index + 1, upperBound: upperBound),
            let closeParenthesis = matchingIndex(
                openingAt: openParenthesis,
                opening: "(",
                closing: ")",
                upperBound: upperBound
            )
        else {
            return nil
        }
        let nameToken = tokens[index + 1]
        let parameters = parseParameters(in: (openParenthesis + 1)..<closeParenthesis)
        var cursor = closeParenthesis + 1
        var returnType: AdaScriptType?
        if cursor + 1 < upperBound, tokens[cursor].text == "-", tokens[cursor + 1].text == ">" {
            cursor += 2
            if let parsedType = parseTypeReference(at: cursor, upperBound: upperBound) {
                returnType = parsedType.value
                cursor = parsedType.nextIndex
            }
        } else if cursor < upperBound, tokens[cursor].text == ":" {
            cursor += 1
            if let parsedType = parseTypeReference(at: cursor, upperBound: upperBound) {
                returnType = parsedType.value
                cursor = parsedType.nextIndex
            }
        }

        var bodyRange: Range<Int>?
        var endIndex = closeParenthesis
        if let openBrace = nextToken("{", atOrAfter: cursor, upperBound: upperBound),
            let closeBrace = matchingIndex(openingAt: openBrace, opening: "{", closing: "}", upperBound: upperBound) {
            bodyRange = (openBrace + 1)..<closeBrace
            endIndex = closeBrace
        } else if let semicolon = nextToken(";", atOrAfter: cursor, upperBound: upperBound) {
            endIndex = semicolon
        }
        let syntax = AdaScriptFunctionSyntax(
            annotations: annotations,
            isAsync: isAsync,
            name: nameToken.text,
            parameters: parameters,
            range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[endIndex].range.end),
            returnType: returnType,
            visibility: visibility
        )
        return (AdaScriptParsedFunction(bodyRange: bodyRange, syntax: syntax), endIndex + 1)
    }

    private func parseParameters(in range: Range<Int>) -> [AdaScriptParameterSyntax] {
        splitTopLevel(range, separator: ",").compactMap { parameterRange in
            var cursor = parameterRange.lowerBound
            while cursor < parameterRange.upperBound, tokens[cursor].text == "@" {
                guard let annotation = parseAnnotation(at: cursor, upperBound: parameterRange.upperBound) else {
                    break
                }
                cursor = annotation.nextIndex
            }
            guard cursor < parameterRange.upperBound, tokens[cursor].kind == .identifier else {
                return nil
            }
            let nameToken = tokens[cursor]
            cursor += 1
            var declaredType: AdaScriptType?
            if cursor < parameterRange.upperBound, tokens[cursor].text == ":" {
                cursor += 1
                if let parsedType = parseTypeReference(at: cursor, upperBound: parameterRange.upperBound) {
                    declaredType = parsedType.value
                    cursor = parsedType.nextIndex
                }
            }
            let hasDefaultValue = (cursor..<parameterRange.upperBound).contains { tokens[$0].text == "=" }
            return AdaScriptParameterSyntax(
                declaredType: declaredType,
                hasDefaultValue: hasDefaultValue,
                name: nameToken.text,
                range: nameToken.range
            )
        }
    }

    private func parseBinding(
        at index: Int,
        annotations: [AdaScriptAnnotationSyntax],
        visibility: AdaScriptDeclarationVisibility,
        upperBound: Int
    ) -> (value: AdaScriptParsedBinding, nextIndex: Int)? {
        guard index + 1 < upperBound, tokens[index + 1].kind == .identifier else {
            return nil
        }
        let nameToken = tokens[index + 1]
        var cursor = index + 2
        var declaredType: AdaScriptType?
        if cursor < upperBound, tokens[cursor].text == ":" {
            cursor += 1
            if let parsedType = parseTypeReference(at: cursor, upperBound: upperBound) {
                declaredType = parsedType.value
                cursor = parsedType.nextIndex
            }
        }

        let endIndex = bindingEndIndex(from: cursor, upperBound: upperBound)
        var initializerRange: Range<Int>?
        if cursor < endIndex, tokens[cursor].text == "=" {
            initializerRange = (cursor + 1)..<endIndex
        }
        let syntax = AdaScriptBindingSyntax(
            annotations: annotations,
            declaredType: declaredType,
            isConstant: tokens[index].text == "const",
            name: nameToken.text,
            range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[max(index + 1, endIndex - 1)].range.end),
            visibility: visibility
        )
        return (AdaScriptParsedBinding(initializerRange: initializerRange, syntax: syntax), max(index + 2, endIndex + 1))
    }

    private func parseTypeReference(at index: Int, upperBound: Int) -> (value: AdaScriptType, nextIndex: Int)? {
        guard index < upperBound else {
            return nil
        }
        if tokens[index].text == "[" {
            guard let close = matchingIndex(openingAt: index, opening: "[", closing: "]", upperBound: upperBound) else {
                return nil
            }
            if let colon = firstTopLevelToken(":", in: (index + 1)..<close),
                let key = parseTypeReference(at: index + 1, upperBound: colon),
                let value = parseTypeReference(at: colon + 1, upperBound: close) {
                return (.map(key: key.value, value: value.value), close + 1)
            }
            let element = parseTypeReference(at: index + 1, upperBound: close)?.value ?? .unknown
            return (.list(element), close + 1)
        }
        guard tokens[index].kind == .identifier else {
            return nil
        }
        let name = tokens[index].text
        if index + 1 < upperBound, tokens[index + 1].text == "<",
            let close = matchingIndex(openingAt: index + 1, opening: "<", closing: ">", upperBound: upperBound) {
            let arguments = splitTopLevel((index + 2)..<close, separator: ",").compactMap { range in
                parseTypeReference(at: range.lowerBound, upperBound: range.upperBound)?.value
            }
            if name == "List", let element = arguments.first {
                return (.list(element), close + 1)
            }
            if name == "Map", arguments.count == 2 {
                return (.map(key: arguments[0], value: arguments[1]), close + 1)
            }
        }
        return (AdaScriptType(spelling: name), index + 1)
    }

    private func bindingEndIndex(from index: Int, upperBound: Int) -> Int {
        guard index < upperBound else {
            return upperBound
        }
        if tokens[index].text == "{",
            let close = matchingIndex(openingAt: index, opening: "{", closing: "}", upperBound: upperBound) {
            return close + 1
        }
        var depths = DelimiterDepth()
        var cursor = index
        while cursor < upperBound {
            let token = tokens[cursor]
            depths.consume(token.text)
            if depths.isTopLevel, token.text == ";" {
                return cursor
            }
            if depths.isTopLevel, token.text == "}" {
                return cursor
            }
            if depths.isTopLevel, cursor > index, token.range.start.line > tokens[cursor - 1].range.start.line,
                Self.startsDeclaration.contains(token.text) {
                return cursor
            }
            cursor += 1
        }
        return upperBound
    }

    private func splitTopLevel(_ range: Range<Int>, separator: String) -> [Range<Int>] {
        guard !range.isEmpty else {
            return []
        }
        var result: [Range<Int>] = []
        var start = range.lowerBound
        var depths = DelimiterDepth()
        for index in range {
            let token = tokens[index]
            if depths.isTopLevel, token.text == separator {
                if start < index {
                    result.append(start..<index)
                }
                start = index + 1
            } else {
                depths.consume(token.text)
            }
        }
        if start < range.upperBound {
            result.append(start..<range.upperBound)
        }
        return result
    }

    private func firstTopLevelToken(_ text: String, in range: Range<Int>) -> Int? {
        var depths = DelimiterDepth()
        for index in range {
            if depths.isTopLevel, tokens[index].text == text {
                return index
            }
            depths.consume(tokens[index].text)
        }
        return nil
    }

    private func nextToken(_ text: String, after index: Int, upperBound: Int) -> Int? {
        nextToken(text, atOrAfter: index + 1, upperBound: upperBound)
    }

    private func nextToken(_ text: String, atOrAfter index: Int, upperBound: Int) -> Int? {
        var cursor = index
        while cursor < upperBound {
            if tokens[cursor].text == text {
                return cursor
            }
            if tokens[cursor].text == ";" || tokens[cursor].text == "}" {
                return nil
            }
            cursor += 1
        }
        return nil
    }

    private func matchingIndex(
        openingAt index: Int,
        opening: String,
        closing: String,
        upperBound: Int
    ) -> Int? {
        var depth = 0
        for cursor in index..<upperBound {
            if tokens[cursor].text == opening {
                depth += 1
            } else if tokens[cursor].text == closing {
                depth -= 1
                if depth == 0 {
                    return cursor
                }
            }
        }
        return nil
    }

    private static let startsDeclaration: Set<String> = [
        "async", "class", "const", "enum", "extern", "func", "private", "public", "static", "struct", "var",
    ]
}

private struct ParsedDeclarations {
    var bindings: [AdaScriptParsedBinding] = []
    var functions: [AdaScriptParsedFunction] = []
    var tests: [AdaScriptTestSyntax] = []
    var types: [AdaScriptParsedType] = []
}

private struct DeclarationPrefix {
    var annotations: [AdaScriptAnnotationSyntax]
    var isAsync: Bool
    var isPrivate: Bool
    var nextIndex: Int
    var startIndex: Int
}

private struct DelimiterDepth {
    private var braces = 0
    private var brackets = 0
    private var parentheses = 0

    var isTopLevel: Bool {
        braces == 0 && brackets == 0 && parentheses == 0
    }

    mutating func consume(_ token: String) {
        switch token {
        case "(": parentheses += 1
        case ")": parentheses = max(0, parentheses - 1)
        case "[": brackets += 1
        case "]": brackets = max(0, brackets - 1)
        case "{": braces += 1
        case "}": braces = max(0, braces - 1)
        default: break
        }
    }
}

// MARK: Imports and annotation uses

extension AdaScriptSyntaxParser {
    func parseImports() -> (declarations: [AdaScriptImportSyntax], diagnostics: [AdaScriptImportDiagnostic]) {
        var declarations: [AdaScriptImportSyntax] = []
        var diagnostics: [AdaScriptImportDiagnostic] = []
        var depth = DelimiterDepth()
        var index = 0
        while index < tokens.count {
            let token = tokens[index]
            if depth.isTopLevel, token.kind == .identifier, token.text == "import", !(index > 0 && tokens[index - 1].text == ".") {
                switch parseImport(at: index) {
                case let .success(declaration, next):
                    declarations.append(declaration)
                    index = next
                case let .failure(diagnostic, next):
                    diagnostics.append(diagnostic)
                    index = next
                }
                continue
            }
            depth.consume(token.text)
            index += 1
        }
        return (declarations, diagnostics)
    }

    private enum ImportParse {
        case success(AdaScriptImportSyntax, Int)
        case failure(AdaScriptImportDiagnostic, Int)
    }

    private func parseImport(at start: Int) -> ImportParse {
        func fail(_ message: String, at index: Int) -> ImportParse {
            let token = tokens[min(index, tokens.count - 1)]
            // Resume after the declaration's terminating `;` so one mistake reports once.
            var resume = index
            while resume < tokens.count, tokens[resume].text != ";" { resume += 1 }
            return .failure(AdaScriptImportDiagnostic(message: message, range: token.range), min(resume + 1, tokens.count))
        }
        var cursor = start + 1
        guard cursor < tokens.count else {
            return fail("expected '{ ... }' or '* as Alias' after import", at: start)
        }
        let kind: AdaScriptImportSyntax.Kind
        if tokens[cursor].text == "*" {
            guard cursor + 2 < tokens.count, tokens[cursor + 1].text == "as", tokens[cursor + 2].kind == .identifier else {
                return fail("expected 'as Alias' after '*' in a namespace import", at: cursor)
            }
            kind = .namespace(alias: tokens[cursor + 2].text)
            cursor += 3
        } else if tokens[cursor].text == "{" {
            var bindings: [AdaScriptImportSyntax.Binding] = []
            cursor += 1
            var expectsName = true
            while cursor < tokens.count, tokens[cursor].text != "}" {
                if expectsName, tokens[cursor].kind == .identifier {
                    let nameToken = tokens[cursor]
                    var binding = AdaScriptImportSyntax.Binding(name: nameToken.text, range: nameToken.range)
                    if cursor + 2 < tokens.count, tokens[cursor + 1].text == "as", tokens[cursor + 2].kind == .identifier {
                        binding.alias = tokens[cursor + 2].text
                        binding.range = AdaScriptSourceRange(start: nameToken.range.start, end: tokens[cursor + 2].range.end)
                        cursor += 2
                    }
                    bindings.append(binding)
                    expectsName = false
                } else if !expectsName, tokens[cursor].text == "," {
                    expectsName = true
                } else {
                    return fail(expectsName ? "expected imported identifier" : "expected ',' or '}'", at: cursor)
                }
                cursor += 1
            }
            guard cursor < tokens.count else {
                return fail("unterminated import list", at: start)
            }
            guard !bindings.isEmpty else {
                return fail("expected imported identifier before '}'", at: cursor)
            }
            kind = .selected(bindings)
            cursor += 1
        } else {
            return fail("expected '{ ... }' or '* as Alias' after import", at: cursor)
        }
        guard cursor < tokens.count, tokens[cursor].text == "from" else {
            return fail("expected 'from'", at: min(cursor, tokens.count - 1))
        }
        cursor += 1
        guard cursor < tokens.count, tokens[cursor].kind == .string, let path = unquotedPath(tokens[cursor].text) else {
            return fail("expected quoted module path", at: min(cursor, tokens.count - 1))
        }
        let pathToken = tokens[cursor]
        cursor += 1
        guard cursor < tokens.count, tokens[cursor].text == ";" else {
            return fail("expected ';' after import", at: min(cursor, tokens.count - 1))
        }
        let end = tokens[cursor]
        return .success(
            AdaScriptImportSyntax(
                kind: kind,
                offsets: tokens[start].startOffset..<end.endOffset,
                path: path,
                pathRange: pathToken.range,
                range: AdaScriptSourceRange(start: tokens[start].range.start, end: end.range.end)
            ),
            cursor + 1
        )
    }

    /// The string literal's value with simple backslash escapes resolved.
    private func unquotedPath(_ literal: String) -> String? {
        guard literal.count >= 2, let quote = literal.first, quote == "\"" || quote == "'", literal.last == quote else {
            return nil
        }
        var result = ""
        var escaped = false
        for character in literal.dropFirst().dropLast() {
            if escaped {
                result.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else {
                result.append(character)
            }
        }
        return result
    }

    /// Every `enum Name { a, b = 2, c }`, wherever it appears. Only case names are read.
    private func parseEnums() -> [AdaScriptEnumSyntax] {
        var result: [AdaScriptEnumSyntax] = []
        var index = 0
        while index < tokens.count {
            guard tokens[index].text == "enum", index + 2 < tokens.count, tokens[index + 1].kind == .identifier, tokens[index + 2].text == "{" else {
                index += 1
                continue
            }
            var cases: [String] = []
            var cursor = index + 3
            var expectsCase = true
            while cursor < tokens.count, tokens[cursor].text != "}" {
                if expectsCase, tokens[cursor].kind == .identifier {
                    cases.append(tokens[cursor].text)
                    expectsCase = false
                } else if tokens[cursor].text == "," {
                    expectsCase = true
                }
                cursor += 1
            }
            let end = min(cursor, tokens.count - 1)
            result.append(
                AdaScriptEnumSyntax(
                    cases: cases,
                    name: tokens[index + 1].text,
                    range: AdaScriptSourceRange(start: tokens[index].range.start, end: tokens[end].range.end)
                )
            )
            index = cursor
        }
        return result
    }

    /// Every `@name(...)` in source order, wherever it appears, with its literal arguments.
    private func parseAllAnnotations() -> [AdaScriptAnnotationSyntax] {
        var result: [AdaScriptAnnotationSyntax] = []
        var index = 0
        while index < tokens.count {
            if tokens[index].text == "@", let parsed = parseAnnotation(at: index, upperBound: tokens.count) {
                result.append(parsed.value)
                index = parsed.nextIndex
            } else {
                index += 1
            }
        }
        return result
    }

    func parseAnnotationUses() -> [AdaScriptAnnotationUse] {
        // Type bodies, innermost last, so a member knows its owner.
        var typeBodies: [(name: String, open: Int, close: Int)] = []
        for index in tokens.indices where ["class", "struct", "enum"].contains(tokens[index].text) {
            guard index + 1 < tokens.count, tokens[index + 1].kind == .identifier,
                let open = nextToken("{", after: index + 1, upperBound: tokens.count),
                let close = matchingIndex(openingAt: open, opening: "{", closing: "}", upperBound: tokens.count)
            else { continue }
            typeBodies.append((tokens[index + 1].text, open, close))
        }
        var uses: [AdaScriptAnnotationUse] = []
        var parentheses = 0
        for index in tokens.indices {
            let token = tokens[index]
            if token.text == "(" { parentheses += 1 } else if token.text == ")" { parentheses = max(0, parentheses - 1) }
            guard token.text == "@", index + 1 < tokens.count, tokens[index + 1].kind == .identifier else {
                continue
            }
            let name = tokens[index + 1].text
            let range = AdaScriptSourceRange(start: token.range.start, end: tokens[index + 1].range.end)
            let owner = typeBodies.last { $0.open < index && index < $0.close }
            // Skip this annotation's arguments, any further annotations, and modifiers to reach the declaration.
            var cursor = index + 2
            if cursor < tokens.count, tokens[cursor].text == "(",
                let close = matchingIndex(openingAt: cursor, opening: "(", closing: ")", upperBound: tokens.count) {
                cursor = close + 1
            }
            while cursor < tokens.count {
                if tokens[cursor].text == "@", cursor + 1 < tokens.count, tokens[cursor + 1].kind == .identifier {
                    cursor += 2
                    if cursor < tokens.count, tokens[cursor].text == "(",
                        let close = matchingIndex(openingAt: cursor, opening: "(", closing: ")", upperBound: tokens.count) {
                        cursor = close + 1
                    }
                } else if Self.declarationModifiers.contains(tokens[cursor].text) {
                    cursor += 1
                } else {
                    break
                }
            }
            let keyword = cursor < tokens.count ? tokens[cursor].text : ""
            let declaredName = cursor + 1 < tokens.count && tokens[cursor + 1].kind == .identifier ? tokens[cursor + 1].text : nil
            let target: AdaScriptAnnotationUse.Target
            if parentheses > 0 {
                target = .parameter
            } else if name == "strict", owner == nil, !(keyword == "func" || keyword == "var" || keyword == "const") {
                target = .module
            } else {
                switch keyword {
                case "class": target = .class
                case "struct": target = .struct
                case "enum": target = .enum
                case "func": target = owner == nil ? .function : .method
                case "var", "const": target = owner == nil ? .variable : .property
                default: target = .module
                }
            }
            uses.append(AdaScriptAnnotationUse(
                name: name,
                range: range,
                target: target,
                targetName: target == .module ? nil : declaredName,
                parentName: owner?.name
            ))
        }
        return uses
    }
}

extension AdaScriptSyntaxParser {
    /// Finds `Alias.member` for namespace imports and bare uses of `as`-renamed names.
    func parseImportUses(_ imports: [AdaScriptImportSyntax]) -> [AdaScriptImportUse] {
        var namespaces = Set<String>()
        var renamed: [String: String] = [:]
        for declaration in imports {
            switch declaration.kind {
            case let .namespace(alias):
                namespaces.insert(alias)
            case let .selected(bindings):
                for binding in bindings {
                    if let alias = binding.alias { renamed[alias] = binding.name }
                }
            }
        }
        guard !namespaces.isEmpty || !renamed.isEmpty else { return [] }
        let importRanges = imports.map(\.offsets)
        var uses: [AdaScriptImportUse] = []
        for index in tokens.indices where tokens[index].kind == .identifier {
            let token = tokens[index]
            // Names inside the import declarations themselves are not uses.
            if importRanges.contains(where: { $0.contains(token.startOffset) }) { continue }
            // `x.Alias` is a member of something else, and `Alias:` before a value is a label, not a reference.
            if index > 0, tokens[index - 1].text == "." { continue }
            if namespaces.contains(token.text), index + 2 < tokens.count, tokens[index + 1].text == ".", tokens[index + 2].kind == .identifier {
                uses.append(AdaScriptImportUse(
                    kind: .namespaceMember(alias: token.text, member: tokens[index + 2].text),
                    offsets: token.startOffset..<tokens[index + 2].startOffset,
                    range: AdaScriptSourceRange(start: token.range.start, end: tokens[index + 2].range.end)
                ))
            } else if let original = renamed[token.text] {
                uses.append(AdaScriptImportUse(
                    kind: .renamed(local: token.text, original: original),
                    offsets: token.startOffset..<token.endOffset,
                    range: token.range
                ))
            }
        }
        return uses
    }
}

extension AdaScriptSyntaxParser {
    /// `private` / `public` written before a top-level declaration.
    func topLevelVisibilityModifiers() -> [Range<Int>] {
        var depth = DelimiterDepth()
        var result: [Range<Int>] = []
        for index in tokens.indices {
            let token = tokens[index]
            if depth.isTopLevel, token.kind == .identifier, token.text == "private" || token.text == "public",
                !(index > 0 && tokens[index - 1].text == "."),
                index + 1 < tokens.count, Self.startsDeclaration.contains(tokens[index + 1].text) {
                result.append(token.startOffset..<token.endOffset)
            }
            depth.consume(token.text)
        }
        return result
    }
}

extension AdaScriptSyntaxParser {
    private static let referenceKeywords: Set<String> = [
        "as", "async", "await", "break", "case", "class", "const", "continue", "else", "enum", "extern", "false", "for", "from", "func",
        "if", "import", "in", "is", "not", "null", "private", "public", "return", "self", "static", "struct", "super", "switch", "true",
        "undefined", "var", "while",
    ]

    /// Names declared anywhere in the file, including parameters and loop variables.
    func declaredNames() -> Set<String> {
        var names = Set<String>()
        for index in tokens.indices {
            let token = tokens[index].text
            if ["var", "const", "func", "class", "struct", "enum"].contains(token),
                index + 1 < tokens.count, tokens[index + 1].kind == .identifier {
                names.insert(tokens[index + 1].text)
            }
            if token == "func", index + 2 < tokens.count, let open = nextToken("(", after: index + 1, upperBound: tokens.count),
                let close = matchingIndex(openingAt: open, opening: "(", closing: ")", upperBound: tokens.count) {
                for parameter in parseParameters(in: (open + 1)..<close) { names.insert(parameter.name) }
            }
            if token == "for", index + 2 < tokens.count, tokens[index + 1].text == "(" {
                var cursor = index + 2
                if cursor < tokens.count, tokens[cursor].text == "var" || tokens[cursor].text == "const" { cursor += 1 }
                if cursor < tokens.count, tokens[cursor].kind == .identifier { names.insert(tokens[cursor].text) }
            }
        }
        return names
    }

    /// Bare identifiers: not `x.member`, not `@annotation`, not `label:` in an argument list, not inside an import.
    func nameReferences(excluding excluded: [Range<Int>]) -> [AdaScriptNameReference] {
        var result: [AdaScriptNameReference] = []
        for index in tokens.indices {
            let token = tokens[index]
            guard token.kind == .identifier, !Self.referenceKeywords.contains(token.text) else { continue }
            if excluded.contains(where: { $0.contains(token.startOffset) }) { continue }
            if index > 0, [".", "@"].contains(tokens[index - 1].text) { continue }
            if index + 1 < tokens.count, tokens[index + 1].text == ":", index > 0, ["(", ","].contains(tokens[index - 1].text) { continue }
            result.append(AdaScriptNameReference(name: token.text, range: token.range))
        }
        return result
    }
}
