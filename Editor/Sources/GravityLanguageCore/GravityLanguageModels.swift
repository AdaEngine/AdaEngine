import Foundation

public struct GravitySourcePosition: Equatable, Hashable, Sendable {
    public var line: Int
    public var utf16Column: Int

    public init(line: Int, utf16Column: Int) {
        self.line = line
        self.utf16Column = utf16Column
    }
}

public struct GravitySourceRange: Equatable, Hashable, Sendable {
    public var start: GravitySourcePosition
    public var end: GravitySourcePosition

    public init(start: GravitySourcePosition, end: GravitySourcePosition) {
        self.start = start
        self.end = end
    }

    public func contains(_ position: GravitySourcePosition) -> Bool {
        start <= position && position <= end
    }
}

extension GravitySourcePosition: Comparable {
    public static func < (lhs: GravitySourcePosition, rhs: GravitySourcePosition) -> Bool {
        lhs.line == rhs.line ? lhs.utf16Column < rhs.utf16Column : lhs.line < rhs.line
    }
}

public enum GravitySymbolKind: Int, Equatable, Hashable, Sendable {
    case method = 6
    case property = 7
    case field = 8
    case function = 12
    case variable = 13
    case constant = 14
    case string = 15
    case number = 16
    case boolean = 17
    case array = 18
    case `class` = 5
    case `struct` = 23
    case `enum` = 10
}

public struct GravitySymbol: Equatable, Hashable, Sendable {
    public var name: String
    public var kind: GravitySymbolKind
    public var detail: String
    public var range: GravitySourceRange
    public var members: [Self]

    public init(
        name: String,
        kind: GravitySymbolKind,
        detail: String,
        range: GravitySourceRange,
        members: [Self] = []
    ) {
        self.name = name
        self.kind = kind
        self.detail = detail
        self.range = range
        self.members = members
    }
}

public enum GravityCompletionKind: Int, Equatable, Hashable, Sendable {
    case method = 2
    case function = 3
    case variable = 6
    case `class` = 7
    case property = 10
    case keyword = 14
    case snippet = 15
    case `struct` = 22
    case `enum` = 13
}

public struct GravityCompletion: Equatable, Hashable, Sendable {
    public var label: String
    public var detail: String
    public var insertText: String
    public var kind: GravityCompletionKind
    public var replacementRange: GravitySourceRange
    public var sortText: String

    public init(
        label: String,
        detail: String,
        insertText: String,
        kind: GravityCompletionKind,
        replacementRange: GravitySourceRange,
        sortText: String
    ) {
        self.label = label
        self.detail = detail
        self.insertText = insertText
        self.kind = kind
        self.replacementRange = replacementRange
        self.sortText = sortText
    }
}

public enum GravityDiagnosticSeverity: Int, Equatable, Hashable, Sendable {
    case error = 1
    case warning = 2
}

public struct GravityDiagnostic: Equatable, Hashable, Sendable {
    public var message: String
    public var range: GravitySourceRange
    public var severity: GravityDiagnosticSeverity

    public init(message: String, range: GravitySourceRange, severity: GravityDiagnosticSeverity = .error) {
        self.message = message
        self.range = range
        self.severity = severity
    }
}

public struct GravityImport: Equatable, Hashable, Sendable {
    public var names: [String]
    public var namespace: String?
    public var path: String
    public var range: GravitySourceRange

    public init(
        names: [String],
        namespace: String? = nil,
        path: String,
        range: GravitySourceRange
    ) {
        self.names = names
        self.namespace = namespace
        self.path = path
        self.range = range
    }
}

public struct GravityDocumentAnalysis: Equatable, Sendable {
    public var diagnostics: [GravityDiagnostic]
    public var imports: [GravityImport]
    public var symbols: [GravitySymbol]

    public init(
        diagnostics: [GravityDiagnostic],
        imports: [GravityImport] = [],
        symbols: [GravitySymbol]
    ) {
        self.diagnostics = diagnostics
        self.imports = imports
        self.symbols = symbols
    }
}
