public struct AdaScriptSourcePosition: Equatable, Hashable, Sendable {
    public var line: Int
    public var utf16Column: Int

    public init(line: Int, utf16Column: Int) {
        self.line = line
        self.utf16Column = utf16Column
    }
}

public struct AdaScriptSourceRange: Equatable, Hashable, Sendable {
    public var start: AdaScriptSourcePosition
    public var end: AdaScriptSourcePosition

    public init(start: AdaScriptSourcePosition, end: AdaScriptSourcePosition) {
        self.start = start
        self.end = end
    }
}

/// A type known by AdaScript's static analysis layer. `unknown` means the
/// analyzer could not prove a type, while `any` is an explicit dynamic boundary.
public indirect enum AdaScriptType: Equatable, Hashable, Sendable {
    case any
    case bool
    case float
    case int
    case list(Self)
    case map(key: Self, value: Self)
    case named(String)
    case null
    case query([String])
    case queryRow([String])
    case string
    case unknown
    case void

    public init(spelling: String) {
        switch spelling.lowercased() {
        case "any", "dynamic", "variant":
            self = .any
        case "bool", "boolean":
            self = .bool
        case "float", "double", "number":
            self = .float
        case "int", "integer":
            self = .int
        case "null":
            self = .null
        case "string":
            self = .string
        case "void":
            self = .void
        default:
            self = .named(spelling)
        }
    }

    public var displayName: String {
        switch self {
        case .any: "Any"
        case .bool: "Bool"
        case .float: "Float"
        case .int: "Int"
        case let .list(element): "List<\(element.displayName)>"
        case let .map(key, value): "Map<\(key.displayName), \(value.displayName)>"
        case let .named(name): name
        case .null: "Null"
        case .query: "$AdaQueryCollection"
        case .queryRow: "$AdaEntity"
        case .string: "String"
        case .unknown: "Unknown"
        case .void: "Void"
        }
    }

    public func accepts(_ value: Self) -> Bool {
        if self == .any || self == .unknown || value == .any || value == .unknown {
            return true
        }
        if self == value {
            return true
        }
        if self == .float, value == .int {
            return true
        }
        if value == .null {
            return true
        }
        return switch (self, value) {
        case let (.list(expected), .list(actual)):
            expected.accepts(actual)
        case let (.map(expectedKey, expectedValue), .map(actualKey, actualValue)):
            expectedKey.accepts(actualKey) && expectedValue.accepts(actualValue)
        default:
            false
        }
    }
}

/// A literal inside an annotation argument list, for example `"id"`, `3`, `true`, `Game.Health as health` or `[a, b]`.
public indirect enum AdaScriptAnnotationValue: Equatable, Hashable, Sendable {
    case bool(Bool)
    /// A bare or dotted name, optionally `as alias`: `Game.Health` and `Game.Health as health`.
    case identifier(String)
    case list([AdaScriptAnnotationValue])
    case number(String)
    /// The unescaped string content, without its quotes.
    case string(String)
}

/// One annotation argument: `label: value`, or just `value` when `label` is `nil`.
public struct AdaScriptAnnotationArgument: Equatable, Hashable, Sendable {
    public var label: String?
    public var value: AdaScriptAnnotationValue

    public init(label: String? = nil, value: AdaScriptAnnotationValue) {
        self.label = label
        self.value = value
    }
}

public struct AdaScriptAnnotationSyntax: Equatable, Hashable, Sendable {
    /// Identifier-only arguments, kept for placement and capability checks.
    public var arguments: [String]
    public var name: String
    /// Source offsets from the `@` through the closing parenthesis, when there is one.
    public var offsets: Range<Int>
    /// Why ``values`` is incomplete (an unterminated list or an unsupported value), or `nil`.
    public var problem: String?
    public var range: AdaScriptSourceRange
    /// Every argument with its label and literal value, in source order.
    public var values: [AdaScriptAnnotationArgument]

    public init(
        arguments: [String] = [],
        name: String,
        offsets: Range<Int> = 0..<0,
        problem: String? = nil,
        range: AdaScriptSourceRange,
        values: [AdaScriptAnnotationArgument] = []
    ) {
        self.arguments = arguments
        self.name = name
        self.offsets = offsets
        self.problem = problem
        self.range = range
        self.values = values
    }

    /// The value of the argument labelled `label`.
    public func value(labelled label: String) -> AdaScriptAnnotationValue? {
        values.first { $0.label == label }?.value
    }

    /// The unlabelled arguments, in order.
    public var positionalValues: [AdaScriptAnnotationValue] {
        values.filter { $0.label == nil }.map(\.value)
    }
}

public struct AdaScriptBindingSyntax: Equatable, Hashable, Sendable {
    public var annotations: [AdaScriptAnnotationSyntax]
    public var declaredType: AdaScriptType?
    public var isConstant: Bool
    public var name: String
    public var range: AdaScriptSourceRange
    public var visibility: AdaScriptDeclarationVisibility

    public init(
        annotations: [AdaScriptAnnotationSyntax] = [],
        declaredType: AdaScriptType? = nil,
        isConstant: Bool,
        name: String,
        range: AdaScriptSourceRange,
        visibility: AdaScriptDeclarationVisibility = .public
    ) {
        self.annotations = annotations
        self.declaredType = declaredType
        self.isConstant = isConstant
        self.name = name
        self.range = range
        self.visibility = visibility
    }
}

public struct AdaScriptParameterSyntax: Equatable, Hashable, Sendable {
    public var declaredType: AdaScriptType?
    public var hasDefaultValue: Bool
    public var name: String
    public var range: AdaScriptSourceRange

    public init(declaredType: AdaScriptType? = nil, hasDefaultValue: Bool = false, name: String, range: AdaScriptSourceRange) {
        self.declaredType = declaredType
        self.hasDefaultValue = hasDefaultValue
        self.name = name
        self.range = range
    }
}

public struct AdaScriptFunctionSyntax: Equatable, Hashable, Sendable {
    public var annotations: [AdaScriptAnnotationSyntax]
    public var isAsync: Bool
    public var name: String
    public var parameters: [AdaScriptParameterSyntax]
    public var range: AdaScriptSourceRange
    public var returnType: AdaScriptType?
    public var visibility: AdaScriptDeclarationVisibility

    public init(
        annotations: [AdaScriptAnnotationSyntax] = [],
        isAsync: Bool,
        name: String,
        parameters: [AdaScriptParameterSyntax],
        range: AdaScriptSourceRange,
        returnType: AdaScriptType? = nil,
        visibility: AdaScriptDeclarationVisibility = .public
    ) {
        self.annotations = annotations
        self.isAsync = isAsync
        self.name = name
        self.parameters = parameters
        self.range = range
        self.returnType = returnType
        self.visibility = visibility
    }
}

public struct AdaScriptTypeSyntax: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case `class`
        case `enum`
        case `struct`
    }

    public var annotations: [AdaScriptAnnotationSyntax]
    public var bindings: [AdaScriptBindingSyntax]
    public var functions: [AdaScriptFunctionSyntax]
    public var kind: Kind
    public var name: String
    public var range: AdaScriptSourceRange
    public var visibility: AdaScriptDeclarationVisibility

    public init(
        annotations: [AdaScriptAnnotationSyntax] = [],
        bindings: [AdaScriptBindingSyntax] = [],
        functions: [AdaScriptFunctionSyntax] = [],
        kind: Kind,
        name: String,
        range: AdaScriptSourceRange,
        visibility: AdaScriptDeclarationVisibility = .public
    ) {
        self.annotations = annotations
        self.bindings = bindings
        self.functions = functions
        self.kind = kind
        self.name = name
        self.range = range
        self.visibility = visibility
    }
}

/// One top-level `@test` function.
public struct AdaScriptTestSyntax: Equatable, Hashable, Sendable {
    public var annotationRange: AdaScriptSourceRange
    /// The string given to `@test("…")`, or the function name.
    public var displayName: String
    public var isAsync: Bool
    public var name: String
    /// Character offsets from the first annotation to the closing brace, so stripping removes the whole declaration.
    public var offsets: Range<Int>
    public var parameterCount: Int
    public var range: AdaScriptSourceRange

    public init(
        annotationRange: AdaScriptSourceRange,
        displayName: String,
        isAsync: Bool,
        name: String,
        offsets: Range<Int>,
        parameterCount: Int,
        range: AdaScriptSourceRange
    ) {
        self.annotationRange = annotationRange
        self.displayName = displayName
        self.isAsync = isAsync
        self.name = name
        self.offsets = offsets
        self.parameterCount = parameterCount
        self.range = range
    }
}

/// A script `enum` and its case names in declaration order. Explicit raw values (`b = 2`) are ignored.
public struct AdaScriptEnumSyntax: Equatable, Hashable, Sendable {
    /// Case names as written, so a duplicate stays visible to the consumer that rejects it.
    public var cases: [String]
    public var name: String
    public var range: AdaScriptSourceRange

    public init(cases: [String], name: String, range: AdaScriptSourceRange) {
        self.cases = cases
        self.name = name
        self.range = range
    }
}

public struct AdaScriptSyntaxTree: Equatable, Sendable {
    /// Every `@name` that appears in code, with its position and what it is attached to.
    public var annotationUses: [AdaScriptAnnotationUse]
    /// Every annotation in source order with its labelled literal arguments, whatever it is attached to.
    public var annotations: [AdaScriptAnnotationSyntax]
    public var bindings: [AdaScriptBindingSyntax]
    /// Every name declared anywhere in the file: variables, constants, functions, types, parameters, and loop variables.
    public var declaredNames: Set<String>
    /// Every constant after a declaration's `=`, in source order, keyed by the offset of that `=`.
    public var defaultValues: [AdaScriptDefaultValueSyntax]
    /// Every `enum Name { ... }`, including enums declared inside other types.
    public var enums: [AdaScriptEnumSyntax]
    public var functions: [AdaScriptFunctionSyntax]
    public var importDiagnostics: [AdaScriptImportDiagnostic]
    public var importUses: [AdaScriptImportUse]
    public var imports: [AdaScriptImportSyntax]
    public var isStrict: Bool
    public var path: String
    /// Bare identifiers that are not member accesses or argument labels.
    public var references: [AdaScriptNameReference]
    /// Top-level `@test` functions, in source order.
    public var tests: [AdaScriptTestSyntax]
    public var types: [AdaScriptTypeSyntax]
    /// Character offsets of top-level `private`/`public` keywords. Gravity only accepts access specifiers
    /// on members, so lowering removes these after visibility has been read.
    public var visibilityModifierOffsets: [Range<Int>]

    public init(
        annotationUses: [AdaScriptAnnotationUse] = [],
        annotations: [AdaScriptAnnotationSyntax] = [],
        bindings: [AdaScriptBindingSyntax] = [],
        declaredNames: Set<String> = [],
        defaultValues: [AdaScriptDefaultValueSyntax] = [],
        enums: [AdaScriptEnumSyntax] = [],
        functions: [AdaScriptFunctionSyntax] = [],
        importDiagnostics: [AdaScriptImportDiagnostic] = [],
        importUses: [AdaScriptImportUse] = [],
        imports: [AdaScriptImportSyntax] = [],
        isStrict: Bool = false,
        path: String,
        references: [AdaScriptNameReference] = [],
        tests: [AdaScriptTestSyntax] = [],
        types: [AdaScriptTypeSyntax] = [],
        visibilityModifierOffsets: [Range<Int>] = []
    ) {
        self.annotationUses = annotationUses
        self.annotations = annotations
        self.bindings = bindings
        self.declaredNames = declaredNames
        self.defaultValues = defaultValues
        self.enums = enums
        self.functions = functions
        self.importDiagnostics = importDiagnostics
        self.importUses = importUses
        self.imports = imports
        self.isStrict = isStrict
        self.path = path
        self.references = references
        self.tests = tests
        self.types = types
        self.visibilityModifierOffsets = visibilityModifierOffsets
    }
}

public enum AdaScriptTypeCheckingMode: String, Codable, Equatable, Hashable, Sendable {
    case dynamic
    case strict
}

public struct AdaScriptCallableType: Equatable, Hashable, Sendable {
    public var parameters: [AdaScriptType]
    public var returnType: AdaScriptType

    public init(parameters: [AdaScriptType], returnType: AdaScriptType = .unknown) {
        self.parameters = parameters
        self.returnType = returnType
    }
}

public enum AdaScriptMemberKind: Equatable, Hashable, Sendable {
    case method
    case property
}

public struct AdaScriptMemberType: Equatable, Hashable, Sendable {
    public var callable: AdaScriptCallableType?
    public var detail: String?
    public var insertText: String?
    public var kind: AdaScriptMemberKind
    public var type: AdaScriptType

    public init(
        type: AdaScriptType,
        callable: AdaScriptCallableType? = nil,
        detail: String? = nil,
        insertText: String? = nil,
        kind: AdaScriptMemberKind = .property
    ) {
        self.callable = callable
        self.detail = detail
        self.insertText = insertText
        self.kind = kind
        self.type = type
    }
}

/// External types visible to the analyzer. Runtime and editor integrations can
/// extend this catalog without coupling the compiler core to engine modules.
public struct AdaScriptTypeEnvironment: Equatable, Sendable {
    public var functions: [String: AdaScriptCallableType]
    public var members: [String: [String: AdaScriptMemberType]]
    public var values: [String: AdaScriptType]

    public init(
        functions: [String: AdaScriptCallableType] = [:],
        members: [String: [String: AdaScriptMemberType]] = [:],
        values: [String: AdaScriptType] = [:]
    ) {
        self.functions = functions
        self.members = members
        self.values = values
    }

    public mutating func register(schemas: [AdaScriptDataSchema]) {
        for schema in schemas {
            var schemaMembers = Dictionary(uniqueKeysWithValues: schema.fields.map { field in
                (field.name, AdaScriptMemberType(type: field.defaultValue.analysisType))
            })
            if case .resource = schema.kind {
                schemaMembers["available"] = AdaScriptMemberType(
                    type: .bool,
                    callable: AdaScriptCallableType(parameters: [], returnType: .bool),
                    detail: "available() -> Bool — whether an optional resource is bound",
                    insertText: "available()",
                    kind: .method
                )
            }
            members[schema.name] = schemaMembers
        }
    }
}

public struct AdaScriptTypeIssue: Equatable, Hashable, Sendable {
    public enum Kind: Equatable, Hashable, Sendable {
        case argumentType
        case assignmentType
        case memberAccess
        case returnType
    }

    public var kind: Kind
    public var message: String
    public var path: String
    public var range: AdaScriptSourceRange

    public init(kind: Kind, message: String, path: String, range: AdaScriptSourceRange) {
        self.kind = kind
        self.message = message
        self.path = path
        self.range = range
    }
}

public struct AdaScriptSourceAnalysis: Equatable, Sendable {
    public var inferredTypes: [String: AdaScriptType]
    public var syntax: AdaScriptSyntaxTree
    public var typeIssues: [AdaScriptTypeIssue]

    public init(
        inferredTypes: [String: AdaScriptType] = [:],
        syntax: AdaScriptSyntaxTree,
        typeIssues: [AdaScriptTypeIssue] = []
    ) {
        self.inferredTypes = inferredTypes
        self.syntax = syntax
        self.typeIssues = typeIssues
    }
}

public struct AdaScriptModuleAnalysis: Equatable, Sendable {
    public var sources: [AdaScriptSourceAnalysis]

    public init(sources: [AdaScriptSourceAnalysis]) {
        self.sources = sources
    }

    public var typeIssues: [AdaScriptTypeIssue] {
        sources.flatMap(\.typeIssues)
    }

    public func enforcedTypeIssues(mode: AdaScriptTypeCheckingMode) -> [AdaScriptTypeIssue] {
        sources.flatMap { source in
            mode == .strict || source.syntax.isStrict ? source.typeIssues : []
        }
    }

    public func requireValidTypes(mode: AdaScriptTypeCheckingMode) throws {
        let issues = enforcedTypeIssues(mode: mode)
        guard issues.isEmpty else {
            throw AdaScriptTypeCheckingError(issues: issues)
        }
    }
}

public struct AdaScriptTypeCheckingError: Error, Equatable, Sendable, CustomStringConvertible {
    public var issues: [AdaScriptTypeIssue]

    public init(issues: [AdaScriptTypeIssue]) {
        self.issues = issues
    }

    public var description: String {
        issues.map { issue in
            "\(issue.path):\(issue.range.start.line + 1):\(issue.range.start.utf16Column + 1): \(issue.message)"
        }
        .joined(separator: "\n")
    }
}

private extension AdaScriptSchemaField.Value {
    var analysisType: AdaScriptType {
        switch self {
        case .bool: .bool
        case .double: .float
        case .int: .int
        case .string: .string
        case .vector, .color: .list(.float)
        case .enumeration: .string
        case .entity: .int
        case .asset: .string
        }
    }
}
