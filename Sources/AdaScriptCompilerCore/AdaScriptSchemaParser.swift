public enum AdaScriptSchemaParser {
    /// Collects every script `enum` (`enum Name { a, b = 2, c }`) so schema fields can name them.
    /// Only the case names matter to schemas; explicit raw values are accepted and ignored.
    static func collectEnums(_ sources: [AdaScriptCompilerSource]) throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for source in sources.sorted(by: { $0.path < $1.path }) {
            for declaration in AdaScriptSyntax.parse(source: source.source, path: source.path).enums {
                var seen = Set<String>()
                for name in declaration.cases {
                    guard seen.insert(name).inserted else {
                        throw AdaScriptSchemaError.invalidEnum(name: declaration.name, message: "duplicate case '\(name)'")
                    }
                }
                guard !declaration.cases.isEmpty else {
                    throw AdaScriptSchemaError.invalidEnum(name: declaration.name, message: "an enum used by data needs at least one case")
                }
                guard result.updateValue(declaration.cases, forKey: declaration.name) == nil else {
                    throw AdaScriptSchemaError.invalidEnum(name: declaration.name, message: "declared more than once")
                }
            }
        }
        return result
    }

    public static func parse(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptDataSchema] {
        var schemas: [AdaScriptDataSchema] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
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
        // An alias is a key a scene may use, so it must not shadow another schema's name, id, or alias.
        var claimed = ids.union(names)
        for schema in schemas {
            for alias in schema.aliases {
                guard claimed.insert(alias).inserted else {
                    throw AdaScriptSchemaError.duplicateName(alias)
                }
            }
        }
        return schemas
    }

    public static func parseResourceBindings(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptResourceBinding] {
        var bindings: [AdaScriptResourceBinding] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            bindings += try parser.parse().resourceBindings
        }
        return bindings
    }

    public static func parseNetworkCommands(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptNetworkCommandSchema] {
        var schemas: [AdaScriptNetworkCommandSchema] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            schemas += try parser.parse().networkCommands
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

    public static func parseRemoteCommandBindings(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptRemoteCommandBinding] {
        var bindings: [AdaScriptRemoteCommandBinding] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            bindings += try parser.parse().remoteCommandBindings
        }
        return bindings
    }

    public static func parseRPCMethodBindings(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptRPCMethodBinding] {
        var bindings: [AdaScriptRPCMethodBinding] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            bindings += try parser.parse().rpcMethodBindings
        }
        return bindings
    }

    public static func parseScriptables(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptableSchema] {
        var schemas: [AdaScriptableSchema] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            schemas += try parser.parse().scriptables
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

    public static func parseSystemCapabilities(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptSystemCapabilities] {
        var capabilities: [AdaScriptSystemCapabilities] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            capabilities += try parser.parse().systemCapabilities
        }
        return capabilities
    }

    public static func parseTools(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptToolSchema] {
        var schemas: [AdaScriptToolSchema] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            schemas += try parser.parse().tools
        }

        var ids = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateToolID(schema.id)
            }
        }
        return schemas
    }

    public static func parseViews(sources: [AdaScriptCompilerSource]) throws -> [AdaScriptViewSchema] {
        var schemas: [AdaScriptViewSchema] = []
        let enums = try collectEnums(sources)
        for source in sources.sorted(by: { $0.path < $1.path }) {
            var parser = Parser(source: source.source, path: source.path, enums: enums)
            schemas += try parser.parse().views
        }

        var ids = Set<String>()
        var names = Set<String>()
        for schema in schemas {
            guard ids.insert(schema.id).inserted else {
                throw AdaScriptSchemaError.duplicateID(schema.id)
            }
            guard names.insert(schema.className).inserted else {
                throw AdaScriptSchemaError.duplicateName(schema.className)
            }
        }
        return schemas
    }
}

struct Annotation {
    let arguments: [String: Literal]
    let name: String
    let positionalArguments: [Literal]

}

enum Literal {
    case bool(Bool)
    case identifier(String)
    case list([Self])
    case number(String)
    case string(String)

    init(_ value: AdaScriptAnnotationValue) {
        switch value {
        case let .bool(value): self = .bool(value)
        case let .identifier(value): self = .identifier(value)
        case let .list(values): self = .list(values.map(Self.init))
        case let .number(value): self = .number(value)
        case let .string(value): self = .string(value)
        }
    }
}

struct Token {
    enum Kind {
        case identifier
        case number
        case punctuation
        case string
    }

    let endOffset: Int
    let kind: Kind
    let line: Int
    let startOffset: Int
    let text: String
}

struct Parser {
    struct Output {
        var networkCommands: [AdaScriptNetworkCommandSchema] = []
        var remoteCommandBindings: [AdaScriptRemoteCommandBinding] = []
        var rpcMethodBindings: [AdaScriptRPCMethodBinding] = []
        var resourceBindings: [AdaScriptResourceBinding] = []
        var schemas: [AdaScriptDataSchema] = []
        var scriptables: [AdaScriptableSchema] = []
        var systemCapabilities: [AdaScriptSystemCapabilities] = []
        var tools: [AdaScriptToolSchema] = []
        var views: [AdaScriptViewSchema] = []
    }

    let path: String
    let tokens: [Token]
    /// Script enums visible to field declarations, collected across the whole source set.
    let enums: [String: [String]]
    /// Annotations from the shared syntax tree, keyed by the offset of their `@`.
    let annotationsByOffset: [Int: AdaScriptAnnotationSyntax]
    /// Constants after `=`, from the shared syntax tree, keyed by the offset of that `=`.
    let defaultsByEquals: [Int: AdaScriptDefaultValueSyntax]
    var index = 0
    var explicitResourceAccess: [String: AdaScriptResourceBinding.Access] = [:]

    init(source: String, path: String, enums: [String: [String]] = [:]) {
        var lexer = Lexer(source: source)
        self.tokens = lexer.lex()
        self.enums = enums
        self.path = path
        let syntax = AdaScriptSyntaxParser(source: source, path: path).parse().syntax
        self.annotationsByOffset = Dictionary(syntax.annotations.map { ($0.offsets.lowerBound, $0) }, uniquingKeysWith: { first, _ in first })
        self.defaultsByEquals = Dictionary(syntax.defaultValues.map { ($0.equalsOffset, $0) }, uniquingKeysWith: { first, _ in first })
    }
}
