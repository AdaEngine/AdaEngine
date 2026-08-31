import Foundation

public struct AdaScriptCompilerSource: Hashable, Sendable {
    public let path: String
    public let source: String

    public init(path: String, source: String) {
        self.path = path
        self.source = source
    }
}

public struct AdaScriptDataSchema: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case component
        case resource(autoInsert: Bool)
    }

    public let fields: [AdaScriptSchemaField]
    public let id: String
    public let kind: Kind
    public let name: String
    public let sourcePath: String
}

public struct AdaScriptSchemaField: Equatable, Sendable {
    public enum Value: Equatable, Sendable {
        case bool(Bool)
        case double(Double)
        case int(Int64)
        case string(String)
    }

    public let defaultValue: Value
    public let name: String
}

public struct AdaScriptResourceBinding: Equatable, Sendable {
    public let isOptional: Bool
    public let propertyName: String
    public let resourceName: String
    public let systemName: String

    public init(isOptional: Bool, propertyName: String, resourceName: String, systemName: String) {
        self.isOptional = isOptional
        self.propertyName = propertyName
        self.resourceName = resourceName
        self.systemName = systemName
    }
}

public struct AdaScriptSystemCapabilities: Equatable, Sendable {
    public let systemName: String
    public let usesDeferredCommands: Bool

    public init(systemName: String, usesDeferredCommands: Bool) {
        self.systemName = systemName
        self.usesDeferredCommands = usesDeferredCommands
    }
}

public enum AdaScriptSchemaError: Error, Equatable, CustomStringConvertible {
    case duplicateID(String)
    case duplicateName(String)
    case invalid(path: String, message: String)

    public var description: String {
        switch self {
        case .duplicateID(let id):
            "Duplicate Ada Script data id '\(id)'"
        case .duplicateName(let name):
            "Duplicate Ada Script data declaration '\(name)'"
        case let .invalid(path, message):
            "Invalid Ada Script schema in '\(path)': \(message)"
        }
    }
}

public enum AdaScriptSchemaParser {
    public static func parse(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptDataSchema] {
        var schemas: [AdaScriptDataSchema] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            schemas += try parser.parse().schemas
        }

        var ids = Set<String>()
        var names = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateID(schema.id)
            }
            guard names.insert(schema.name).inserted else {
                throw AdaScriptSchemaError.duplicateName(schema.name)
            }
        }
        return schemas
    }

    public static func parseResourceBindings(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptResourceBinding] {
        var bindings: [AdaScriptResourceBinding] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            bindings += try parser.parse().resourceBindings
        }
        return bindings
    }

    public static func parseSystemCapabilities(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptSystemCapabilities] {
        var capabilities: [AdaScriptSystemCapabilities] = []
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path)
            capabilities += try parser.parse().systemCapabilities
        }
        return capabilities
    }
}

private struct Annotation {
    let arguments: [String: Literal]
    let name: String
}

private enum Literal {
    case bool(Bool)
    case identifier(String)
    case number(String)
    case string(String)
}

private struct Token {
    enum Kind {
        case identifier
        case number
        case punctuation
        case string
    }

    let kind: Kind
    let text: String
}

private struct Parser {
    struct Output {
        var resourceBindings: [AdaScriptResourceBinding] = []
        var schemas: [AdaScriptDataSchema] = []
        var systemCapabilities: [AdaScriptSystemCapabilities] = []
    }
    private let path: String
    private let tokens: [Token]
    private var index = 0

    init(source: String, path: String) {
        var lexer = Lexer(source: source)
        self.tokens = lexer.lex()
        self.path = path
    }

    mutating func parse() throws -> Output {
        var output = Output()
        while !isAtEnd {
            let annotations = try parseAnnotations()
            if match("class") {
                guard let name = consumeIdentifier() else {
                    throw error("expected class name")
                }
                if annotations.contains(where: { $0.name == "system" }) {
                    let system = try parseSystemBody(systemName: name)
                    output.resourceBindings += system.resourceBindings
                    output.systemCapabilities.append(system.capabilities)
                } else {
                    try skipDeclarationBody()
                }
                continue
            }
            guard match("struct") else {
                advance()
                continue
            }
            guard let name = consumeIdentifier() else {
                throw error("expected struct name")
            }
            guard let schemaAnnotation = annotations.first(where: { $0.name == "component" || $0.name == "resource" }) else {
                try skipDeclarationBody()
                continue
            }
            output.schemas.append(try parseSchema(name: name, annotation: schemaAnnotation))
        }
        return output
    }
}

private extension Parser {
    private mutating func parseSystemBody(
        systemName: String
    ) throws -> (resourceBindings: [AdaScriptResourceBinding], capabilities: AdaScriptSystemCapabilities) {
        guard match("{") else {
            throw error("expected '{' after system \(systemName)")
        }
        var bindings: [AdaScriptResourceBinding] = []
        var depth = 1
        var usesDeferredCommands = false
        while !isAtEnd, depth > 0 {
            usesDeferredCommands = usesDeferredCommands
                || checkSequence(["context", ".", "world", ".", "commands"])
            if depth == 1, let binding = try parseResourceBinding(systemName: systemName) {
                bindings.append(binding)
                continue
            }
            advanceSystemBody(depth: &depth)
        }
        guard depth == 0 else {
            throw error("unterminated system declaration '\(systemName)'")
        }
        return (
            bindings,
            AdaScriptSystemCapabilities(
                systemName: systemName,
                usesDeferredCommands: usesDeferredCommands
            )
        )
    }

    private mutating func parseResourceBinding(systemName: String) throws -> AdaScriptResourceBinding? {
        let annotations = try parseAnnotations()
        guard let resourceAnnotation = annotations.first(where: { $0.name == "res" }) else {
            return nil
        }
        guard match("var"), let propertyName = consumeIdentifier(), match(":"),
              let resourceName = consumeIdentifier(), match(";") else {
            throw error("@res in \(systemName) must annotate 'var name: ResourceType;'")
        }
        let isOptional: Bool
        if case .bool(let value) = resourceAnnotation.arguments["optional"] {
            isOptional = value
        } else {
            isOptional = false
        }
        return AdaScriptResourceBinding(
            isOptional: isOptional,
            propertyName: propertyName,
            resourceName: resourceName,
            systemName: systemName
        )
    }

    private mutating func advanceSystemBody(depth: inout Int) {
        if match("{") {
            depth += 1
        } else if match("}") {
            depth -= 1
        } else {
            advance()
        }
    }

    private mutating func parseSchema(name: String, annotation: Annotation) throws -> AdaScriptDataSchema {
        guard match("{") else {
            throw error("expected '{' after \(name)")
        }
        let fields = try parseFields(declarationName: name)
        guard match("}") else {
            throw error("unterminated data declaration '\(name)'")
        }
        guard !fields.isEmpty else {
            throw error("@\(annotation.name) \(name) requires at least one @export field")
        }
        return AdaScriptDataSchema(
            fields: fields,
            id: try schemaID(name: name, annotation: annotation),
            kind: schemaKind(annotation),
            name: name,
            sourcePath: path
        )
    }

    private mutating func parseFields(declarationName: String) throws -> [AdaScriptSchemaField] {
        var fields: [AdaScriptSchemaField] = []
        var fieldNames = Set<String>()
        while !isAtEnd, !check("}") {
            let annotations = try parseAnnotations()
            guard match("var") else {
                advance()
                continue
            }
            guard let fieldName = consumeIdentifier() else {
                throw error("expected field name in \(declarationName)")
            }
            if match(":") {
                guard consumeIdentifier() != nil else {
                    throw error("expected field type for \(fieldName)")
                }
            }
            guard match("=") else {
                throw error("field '\(fieldName)' requires a constant default")
            }
            let defaultValue = try parseFieldValue(fieldName: fieldName)
            guard match(";") else {
                throw error("expected ';' after field '\(fieldName)'")
            }
            guard annotations.contains(where: { $0.name == "export" }) else {
                continue
            }
            guard fieldNames.insert(fieldName).inserted else {
                throw error("duplicate field '\(fieldName)' in \(declarationName)")
            }
            fields.append(AdaScriptSchemaField(defaultValue: defaultValue, name: fieldName))
        }
        return fields
    }

    private func schemaID(name: String, annotation: Annotation) throws -> String {
        if case .string(let explicitID) = annotation.arguments["id"] {
            return explicitID
        }
        throw error("@\(annotation.name) on \(name) requires id: \"...\"")
    }

    private func schemaKind(_ annotation: Annotation) -> AdaScriptDataSchema.Kind {
        if annotation.name == "component" {
            return .component
        }
        if case .bool(let value) = annotation.arguments["autoInsert"] {
            return .resource(autoInsert: value)
        }
        return .resource(autoInsert: false)
    }

    private mutating func parseFieldValue(fieldName: String) throws -> AdaScriptSchemaField.Value {
        var sign = ""
        if match("-") {
            sign = "-"
        }
        guard let token = current else {
            throw error("missing default for '\(fieldName)'")
        }
        advance()
        switch token.kind {
        case .string:
            return .string(token.text)
        case .number:
            let value = sign + token.text
            if value.contains(".") || value.lowercased().contains("e") {
                guard let number = Double(value), number.isFinite else {
                    throw error("invalid floating-point default for '\(fieldName)'")
                }
                return .double(number)
            }
            guard let number = Int64(value) else {
                throw error("invalid integer default for '\(fieldName)'")
            }
            return .int(number)
        case .identifier where token.text == "true":
            return .bool(true)
        case .identifier where token.text == "false":
            return .bool(false)
        default:
            throw error("unsupported default for '\(fieldName)'")
        }
    }

    private mutating func parseAnnotations() throws -> [Annotation] {
        var result: [Annotation] = []
        while match("@") {
            guard let name = consumeIdentifier() else {
                throw error("expected annotation name")
            }
            var arguments: [String: Literal] = [:]
            if match("(") {
                while !isAtEnd, !check(")") {
                    if current?.kind == .identifier, checkNext(":") {
                        guard let label = consumeIdentifier(), match(":") else {
                            throw error("invalid named argument in @\(name)")
                        }
                        arguments[label] = try parseLiteral(annotation: name, label: label)
                    } else {
                        try skipAnnotationValue(annotation: name)
                    }
                    if !match(",") {
                        break
                    }
                }
                guard match(")") else {
                    throw error("unterminated @\(name) annotation")
                }
            }
            result.append(Annotation(arguments: arguments, name: name))
        }
        return result
    }

    private mutating func skipAnnotationValue(annotation: String) throws {
        guard !isAtEnd else {
            throw error("missing value in @\(annotation)")
        }
        if match("[") {
            var depth = 1
            while !isAtEnd, depth > 0 {
                if match("[") {
                    depth += 1
                } else if match("]") {
                    depth -= 1
                } else {
                    advance()
                }
            }
            guard depth == 0 else {
                throw error("unterminated list in @\(annotation)")
            }
        } else {
            advance()
        }
    }

    private mutating func parseLiteral(annotation: String, label: String) throws -> Literal {
        guard let token = current else {
            throw error("missing value for @\(annotation) \(label)")
        }
        advance()
        switch token.kind {
        case .string:
            return .string(token.text)
        case .number:
            return .number(token.text)
        case .identifier where token.text == "true":
            return .bool(true)
        case .identifier where token.text == "false":
            return .bool(false)
        case .identifier:
            return .identifier(token.text)
        default:
            throw error("unsupported value for @\(annotation) \(label)")
        }
    }

    private mutating func skipDeclarationBody() throws {
        while !isAtEnd, !check("{") { advance() }
        guard match("{") else {
            return
        }
        var depth = 1
        while !isAtEnd, depth > 0 {
            if match("{") {
                depth += 1
            } else if match("}") {
                depth -= 1
            } else {
                advance()
            }
        }
    }

    private var current: Token? { tokens.indices.contains(index) ? tokens[index] : nil }
    private var isAtEnd: Bool { index >= tokens.count }

    private func check(_ text: String) -> Bool { current?.text == text }

    private func checkNext(_ text: String) -> Bool {
        let nextIndex = index + 1
        return tokens.indices.contains(nextIndex) && tokens[nextIndex].text == text
    }

    private func checkSequence(_ values: [String]) -> Bool {
        guard index + values.count <= tokens.count else {
            return false
        }
        return zip(tokens[index..<(index + values.count)], values).allSatisfy { token, value in
            token.text == value
        }
    }

    @discardableResult
    private mutating func match(_ text: String) -> Bool {
        guard check(text) else {
            return false
        }
        advance()
        return true
    }

    private mutating func consumeIdentifier() -> String? {
        guard let current, current.kind == .identifier else {
            return nil
        }
        advance()
        return current.text
    }

    private mutating func advance() { index += 1 }

    private func error(_ message: String) -> AdaScriptSchemaError {
        .invalid(path: path, message: message)
    }
}

private struct Lexer {
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
